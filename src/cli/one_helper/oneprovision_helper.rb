# -------------------------------------------------------------------------- #
# Copyright 2002-2018, OpenNebula Project, OpenNebula Systems                #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

require 'one_helper'
require 'one_helper/onehost_helper'
require 'yaml'
require 'nokogiri'
require 'open3'
require 'tempfile'
require 'highline'
require 'highline/import'
require 'tmpdir'
require 'json'
require 'logger'
require 'base64'
require 'securerandom'

# Default provision parameters
CONFIG_DEFAULTS = {
    'connection' => {
        'remote_user' => 'root',
        'remote_port' => 22,
        'public_key'  => '/var/lib/one/.ssh/ddc/id_rsa.pub',
        'private_key' => '/var/lib/one/.ssh/ddc/id_rsa'
    }
}

# Ansible params
ANSIBLE_VERSION = [Gem::Version.new('2.5'), Gem::Version.new('2.6')]
ANSIBLE_ARGS = "--ssh-common-args='-o UserKnownHostsFile=/dev/null'"


class OneProvisionCleanupException < Exception
end

class OneProvisionLoopException < Exception
    attr_reader :text

    def initialize(text=nil)
        @text = text
    end
end

###

class OneProvisionHelper < OpenNebulaHelper::OneHelper
    ERROR_OPEN  = "ERROR MESSAGE --8<------"
    ERROR_CLOSE = "ERROR MESSAGE ------>8--"

    def self.rname
        "HOST"
    end

    def self.conf_file
        "oneprovision.yaml"
    end

    def self.state_to_str(id)
        id        = id.to_i
        state_str = Host::HOST_STATES[id]

        Host::SHORT_HOST_STATES[state_str]
    end

    def format_pool(options)
        config_file = self.class.table_conf

        table = CLIHelper::ShowTable.new(config_file, self) do

            column :ID, "ONE identifier for Host", :size=>4 do |d|
                d["ID"]
            end

            column :NAME, "Name of the Host", :left, :size=>15 do |d|
                d["NAME"]
            end

            column :CLUSTER, "Name of the Cluster", :left, :size=>9 do |d|
                OpenNebulaHelper.cluster_str(d["CLUSTER"])
            end

            column :RVM, "Number of Virtual Machines running", :size=>3 do |d|
                d["HOST_SHARE"]["RUNNING_VMS"]
            end

            column :ZVM, "Number of Virtual Machine zombies", :size=>3 do |d|
                d["TEMPLATE"]["TOTAL_ZOMBIES"] || 0
            end

            column :STAT, "Host status", :left, :size=>6 do |d|
                OneHostHelper.state_to_str(d["STATE"])
            end

            column :PROVIDER, "Provision driver", :size=>8 do |d|
                d['TEMPLATE']['PM_MAD'].nil? ? '-' : d['TEMPLATE']['PM_MAD']
            end

            column :VM_MAD, "Virtual Machine driver", :size=>8 do |d|
                d["VM_MAD"]
            end

            default :ID, :NAME, :CLUSTER, :RVM, :PROVIDER, :VM_MAD, :STAT
        end

        table
    end

    def factory(id=nil)
        if id
            OpenNebula::Host.new_with_id(id, @client)
        else
            xml=OpenNebula::Host.build_xml
            OpenNebula::Host.new(xml, @client)
        end
    end

    def factory_pool(user_flag=-2)
        OpenNebula::HostPool.new(@client)
    end

    def check_host(pm_mad)
        if pm_mad.nil? || pm_mad.empty?
            fail('Not a valid bare metal host')
        end
    end

    def check_running_vms(host)
        if host["HOST_SHARE/RUNNING_VMS"].to_i > 0
            fail('There are running VMS on the host, terminate them and then delete the host.')
        end
    end

    def read_config(name)
        devices = []

        begin
            yaml = YAML.load_file(name)

            #TODO: schema check
            yaml['devices'].each do |device|
                ['connection', 'provision', 'configuration'].each do |section|
                    data = CONFIG_DEFAULTS[section] || {}
                    # merge defaults with globals and device specific params
                    data.merge!(yaml[section]) unless yaml[section].nil?
                    data.merge!(device[section]) unless device[section].nil?

                    device[section] = data
                end

                devices << device
            end
        rescue Exception => e
            fail("Failed to read configuration: #{e.to_s}")
        end

        devices
    end

    def try_read_file(name)
        begin
            File.read(name).strip
        rescue
            name
        end
    end

    def create_deployment_file(config, im, vm)
        Nokogiri::XML::Builder.new { |xml|
            xml.HOST do
                xml.NAME "provision-#{SecureRandom.hex(24)}"
                xml.IM_MAD im
                xml.VM_MAD vm
                xml.PM_MAD config['provision']['driver']
                xml.TEMPLATE do
                    xml.IM_MAD im
                    xml.VM_MAD vm
                    xml.PM_MAD config['provision']['driver']
                    xml.PROVISION do
                        config['provision'].each { |key, value|
                            if key != 'driver'
                                xml.send(key.upcase, value)
                            end
                        }
                    end
                    if config['configuration']
                        xml.PROVISION_CONFIGURATION_BASE64 Base64.strict_encode64(config['configuration'].to_yaml)
                    end
                    xml.PROVISION_CONFIGURATION_STATUS 'pending'
                    if config['connection']
                        xml.PROVISION_CONNECTION do
                            config['connection'].each { |key, value|
                                xml.send(key.upcase, value)
                            }
                        end
                    end
                    if config['connection']
                        xml.CONTEXT do
                            if config['connection']['public_key']
                                xml.SSH_PUBLIC_KEY try_read_file(config['connection']['public_key'])
                            end
                        end
                    end
                end
            end
        }.doc.root
    end

    def get_mode(options)
        $logger = Logger.new(STDERR)

        $logger.formatter = proc do |severity, datetime, progname, msg|
            "#{datetime.strftime("%Y-%m-%d %H:%M:%S")} #{severity.ljust(5)} : #{msg}\n"
        end

        if options.has_key? :debug
            $logger.level = Logger::DEBUG
        elsif options.has_key? :verbose
            $logger.level = Logger::INFO
        else
            $logger.level = Logger::UNKNOWN
        end

        $RUN_MODE = :batch if options.has_key? :batch

        $PING_TIMEOUT = options[:ping_timeout] if options.has_key? :ping_timeout
        $PING_RETRIES = options[:ping_retries] if options.has_key? :ping_retries

        if options.has_key? :fail_cleanup
            $FAIL_CHOICE = :cleanup
        elsif options.has_key? :fail_retry
            $FAIL_CHOICE = :retry
            $MAX_RETRIES = options[:fail_retry].to_i
        elsif options.has_key? :fail_skip
            $FAIL_CHOICE = :skip
        elsif options.has_key? :fail_quit
            $FAIL_CHOICE = :quit
        end
    end

    def retry_loop(text, cleanup=$CLEANUP, &block)
        retries = 0

        begin
            block.call
        rescue OneProvisionLoopException => e
            STDERR.puts "ERROR: #{text}\n#{e.text}"

            retries += 1

            exit(-1) if retries > $MAX_RETRIES && $RUN_MODE == :batch

            choice = $FAIL_CHOICE

            if $RUN_MODE == :interactive
                begin
                    cli = HighLine.new($stdin, $stderr)

                    choice = cli.choose do |menu|
                        menu.prompt = "Choose failover method:"
                        menu.choices(:quit, :retry, :skip)
                        menu.choices(:cleanup) if cleanup
                        menu.default = choice
                    end
                rescue EOFError
                    STDERR.puts choice
                rescue Interrupt => e
                    exit(-1)
                end
            end

            if choice == :retry
                retry
            elsif choice == :quit
                exit(-1)
            elsif choice == :skip
                return nil
            elsif choice == :cleanup
                if cleanup
                    raise OneProvisionCleanupException
                else
                    fail('Cleanup unsupported for this operation')
                end
            end

            exit(-1)
        end
    end

    def run(*cmd, &block)
        $logger.debug("Command run: #{cmd.join(' ')}")

        rtn = nil

        begin
            if Hash === cmd.last
                opts = cmd.pop.dup
            else
                opts = {}
            end

            stdin_data = opts.delete(:stdin_data) || ''
            binmode = opts.delete(:binmode)

            Open3.popen3(*cmd, opts) {|i, o, e, t|
                if binmode
                    i.binmode
                    o.binmode
                    e.binmode
                end

                out_reader = Thread.new {o.read}
                err_reader = Thread.new {e.read}

                begin
                    i.write stdin_data
                rescue Errno::EPIPE
                end

                i.close

                rtn = [out_reader.value, err_reader.value, t.value]
            }

            if rtn
                $logger.debug("Command STDOUT: #{rtn[0].strip}") unless rtn[0].empty?
                $logger.debug("Command STDERR: #{rtn[1].strip}") unless rtn[1].empty?

                if rtn[2].success?
                    $logger.debug("Command succeeded")
                else
                    $logger.warn("Command FAILED (code=#{rtn[2].exitstatus}): #{cmd.join(' ')}")
                end
            else
                $logger.error("Command failed on unknown error")
            end
        rescue Interrupt
            fail('Command interrupted')
        rescue Exception => e
            $logger.error("Command exception: #{e.message}")
        end

        rtn
    end

    def pm_driver_action(pm_mad, action, args, host = nil)
        check_host(pm_mad)

        cmd = ["#{REMOTES_LOCATION}/pm/#{pm_mad}/#{action}"]

        args.each do |arg|
            cmd << arg
        end

        # action always gets host ID/name if host defined, same as for VMs:
        # https://github.com/OpenNebula/one/blob/d95b883e38a2cee8ca9230b0dbef58ce3b8d6d6c/src/mad/ruby/OpenNebulaDriver.rb#L95
        unless host.nil?
            cmd << host.id
            cmd << host.name
        end

        unless File.executable? cmd[0]
            $logger.error("Command not found or not executable #{cmd[0]}")
            fail('Driver action script not executable')
        end

        o = nil

        retry_loop "Driver action '#{cmd[0]}' failed" do
            o, e, s = run(cmd.join(' '))

            unless s && s.success?
                err = get_error_message(e)

                text = err.lines[0].strip if err
                text = 'Unknown error' if text == '-'

                raise OneProvisionLoopException.new(text)
            end
        end

        o
    end

    def poll(host)
        poll = monitoring(host)

        if poll.has_key? 'GUEST_IP_ADDRESSES'
            name = poll['GUEST_IP_ADDRESSES'].split(',')[0][1..-1] #TODO
        elsif poll.has_key? 'AWS_PUBLIC_IP_ADDRESS'
            name = poll['AWS_PUBLIC_IP_ADDRESS'][2..-3]
        else
            fail('Failed to get provision name')
        end

        name
    end

    def monitoring(host)
        host.info

        pm_mad = host['TEMPLATE/PM_MAD']
        deploy_id = host['TEMPLATE/PROVISION/DEPLOY_ID']
        name = host.name
        id = host.id

        check_host(pm_mad)

        $logger.info("Monitoring host: #{id.to_s}")

        retry_loop 'Monitoring metrics failed to parse' do
            pm_ret = pm_driver_action(pm_mad, 'poll', [deploy_id, name], host)

            begin
                poll = {}

                pm_ret.split(' ').map{|x| x.split('=', 2)}.each do |key, value|
                    poll[ key.upcase ] = value
                end

                poll
            rescue
                raise OneProvisionLoopException
            end
        end
    end

    def create_host(dfile, deploy_id, options)
        $logger.info("Creating OpenNebula host")

        xhost = OpenNebula::XMLElement.new
        xhost.initialize_xml(dfile, 'HOST')
        xhost.add_element('TEMPLATE/PROVISION', 'DEPLOY_ID' => deploy_id)

        im_mad = options[:im]
        vm_mad = options[:vm]
        cluster = options[:cluster] || ClusterPool::NONE_CLUSTER_ID

        one = OpenNebula::Client.new()
        host = OpenNebula::Host.new(OpenNebula::Host.build_xml, one)
        host.allocate(xhost['//HOST/NAME'], im_mad, vm_mad, cluster)
        host.update(xhost.template_str, true)
        host.offline

        host
    end

    #TODO: is "name" necessary?
    def configure_host(host, name=nil)
        begin
            vars = host['TEMPLATE/PROVISION_CONFIGURATION_BASE64']
            vars = YAML.load(Base64.decode64(vars)) if vars
            vars ||= {}

            # connection parameters
            conn = get_host_template_conn(host)
            conn ||= {}
        rescue Exception => e
            fail("Failed to load host configuration due to #{e.message}")
        end

        configure(name.nil? ? host.name : name, host, vars, conn)
    end

    def delete_host(host)
        host.info

        pm_mad = host['TEMPLATE/PM_MAD']
        deploy_id = host['TEMPLATE/PROVISION/DEPLOY_ID']
        name = host.name

        check_host(pm_mad)

        check_running_vms(host)

        # offline ONE host
        $logger.debug("Offlining OpenNebula host: #{host.id.to_s}")
        host.offline

        # unprovision physical host
        $logger.info("Deleting host: #{host.id.to_s}")
        pm_driver_action(pm_mad, 'cancel', [deploy_id, name], host)

        # delete ONE host
        $logger.debug("Deleting OpenNebula host: #{host.id.to_s}")

        #Fix broken pipe exception on ubuntu 14.04
        host.info

        host.delete
    end

    def reset_host(host, hard)
        if hard
            reset_reboot(host, 'reset', 'Resetting')
            name = poll(host)
            host.rename(name)
        else
            reset_reboot(host, 'reboot', 'Rebooting')
        end
    end

    def reset_reboot(host, action, message)
        host.info

        pm_mad = host['TEMPLATE/PM_MAD']
        deploy_id = host['TEMPLATE/PROVISION/DEPLOY_ID']
        name = host.name

        check_host(pm_mad)

        $logger.debug("Offlining OpenNebula host: #{host.id.to_s}")
        host.offline

        $logger.info("#{message} host: #{host.id.to_s}")
        pm_driver_action(pm_mad, action, [deploy_id, name], host)

        $logger.debug("Enabling OpenNebula host: #{host.id.to_s}")
        host.info
        host.enable
    end

    def check_ansible_version()
        version = Gem::Version.new(`ansible --version`.split[1])

        if (version < ANSIBLE_VERSION[0]) || (version >= ANSIBLE_VERSION[1])
            fail("Unsupported Ansible ver. #{version}, " +
                 "must be >= #{ANSIBLE_VERSION[0]} and < #{ANSIBLE_VERSION[1]}")
        end
    end

    def parse_ansible(stdout)
        begin
            rtn = []
            task = 'UNKNOWN'

            stdout.lines.each do |line|
                task = $1 if line =~ /^TASK \[(.*)\]/i

                if line =~ /^fatal:/i
                    host = 'UNKNOWN'
                    text = ''

                    if line =~ /^fatal: \[([^\]]+)\]: .* => ({.*})$/i
                        host  = $1

                        begin
                            text = JSON.parse($2)['msg'].strip.gsub("\n", ' ')
                            text = "- #{text}"
                        rescue
                        end
                    elsif line =~ /^fatal: \[([^\]]+)\]: .* =>/i
                        host  = $1
                    end

                    rtn << sprintf("- %-15s : TASK[%s] %s", host, task, text)
                end
            end

            rtn.join("\n")
        rescue
            nil
        end
    end

    def ansible_ssh(ansible_dir)
        # Note: We want only to check the working SSH connection, but
        # Ansible "ping" module requires also Python to be installed on
        # the remote side, otherwise fails. So we use only "raw" module with
        # simple command. Python should be installed by "configure" phase later.
        #
        # Older approach with "ping" module:
        # ANSIBLE_CONFIG=#{ansible_dir}/ansible.cfg ansible #{ANSIBLE_ARGS} -m ping all -i #{ansible_dir}/inventory
        o, _e, s = run("ANSIBLE_CONFIG=#{ansible_dir}/ansible.cfg ANSIBLE_BECOME=false ansible #{ANSIBLE_ARGS} -m raw all -i #{ansible_dir}/inventory -a /bin/true")

        if s and s.success?
            hosts = o.lines.count { |l| l =~ /success/i }

            if hosts == 0
                raise OneProvisionLoopException
            else
                return true
            end
        else
            raise OneProvisionLoopException
        end
    end

    def retry_ssh(ansible_dir)
        ret = false
        retries = 0

        while !ret && retries < $PING_RETRIES do
            begin
                ret = ansible_ssh(ansible_dir)
            rescue OneProvisionLoopException => e
                retries += 1
                sleep($PING_TIMEOUT)
            end
        end

        ret
    end

    def try_ssh(ansible_dir)
        $logger.info("Checking working SSH connection")

        if !retry_ssh(ansible_dir)
            retry_loop 'SSH connection is failing' do ansible_ssh(ansible_dir) end
        end
    end

    #TODO: handle exceptions?
    def write_file_log(name, content)
        $logger.debug("Creating #{name}:\n" + content)

        f = File.new(name, "w")
        f.write(content)
        f.close
    end

    #TODO: hosts hash
    #TODO: make it a separate module?
    def generate_ansible_configs(hosts, vars, conn)
        ansible_dir = Dir.mktmpdir()

        $logger.debug("Generating Ansible configurations into #{ansible_dir}")

        # Generate 'inventory' file
        c = "[nodes]\n"
        c << [hosts].flatten.join("\n")
        c << "\n"

        write_file_log("#{ansible_dir}/inventory", c)

        # Generate "group_vars" file
        Dir.mkdir("#{ansible_dir}/group_vars")
        c = YAML.dump(vars)
        write_file_log("#{ansible_dir}/group_vars/all", c)

        # Generate "ansible.cfg" file
        #TODO: what if private_key isn't filename, but content
        #TODO: store private key / packet credentials securely in the ONE
        c = <<-EOT
[defaults]
retry_files_enabled = False
deprecation_warnings = False
display_skipped_hosts = False
callback_whitelist =
stdout_callback = skippy
host_key_checking = False
remote_user = #{conn['remote_user']}
remote_port = #{conn['remote_port']}
private_key_file = #{conn['private_key']}

[privilege_escalation]
become = yes
become_user = root
        EOT

        write_file_log("#{ansible_dir}/ansible.cfg", c)

        #TODO: site.yaml
        #logger(inventoryContent + File.open("#{ANSIBLE_PLAYBOOK_LOCATION}/site.yml").read(), true)

        ansible_dir
    end

    #TODO: expect multiple hosts
    def configure(ip, host, vars, conn, ping=true)
        check_ansible_version

        ansible_dir = generate_ansible_configs(ip, vars, conn)

        try_ssh(ansible_dir) if ping

        # offline ONE host
        $logger.debug("Offlining OpenNebula hosts")
        host.offline
        host.update("PROVISION_CONFIGURATION_STATUS=pending", true)

        retry_loop 'Configuration failed' do
            $logger.info("Configuring hosts")
            o, _e, s = run("ANSIBLE_CONFIG=#{ansible_dir}/ansible.cfg ansible-playbook #{ANSIBLE_ARGS} -i #{ansible_dir}/inventory -e @#{ansible_dir}/group_vars/all #{ANSIBLE_PLAYBOOK_LOCATION}/site.yml")

            if s and s.success?
                host.update("PROVISION_CONFIGURATION_STATUS=configured", true)

                # enable configured ONE host back
                $logger.debug("Enabling OpenNebula hosts")
                host.enable
            else
                host.update("PROVISION_CONFIGURATION_STATUS=error", true)
                errors = parse_ansible(o) if o
                raise OneProvisionLoopException.new(errors)
            end
        end
    end

    def get_host_template_conn(host)
        conn = {}

        #TODO: some nice / generic way (even for configuration?)
        tmpl = host.to_hash['HOST']['TEMPLATE']['PROVISION_CONNECTION']
        tmpl ||= {}
        tmpl.each_pair do |key, value|
            conn[ key.downcase ] = value
        end

        conn
    end

    def get_error_message(text)
        msg = '-'

        if text
            tmp = text.scan(/^#{ERROR_OPEN}\n(.*?)#{ERROR_CLOSE}$/m)
            msg = tmp[0].join(' ').strip if tmp[0]
        end

        msg
    end

    def fail(text, code=-1)
        STDERR.puts "ERROR: #{text}"
        exit(code)
    end
end
