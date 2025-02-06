require 'system/spec_helper'

describe 'service configuration', os: true  do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
  end

  before(:all) do
    load_deployment_spec
    use_static_ip
    use_vip
    @requirements.requirement(deployment, @spec) # 2.5 min on local vsphere
  end

  after(:all) do
    @requirements.cleanup(deployment)
  end

  def instance_reboot
    # turn off vm resurrection
    bosh('update-resurrection off')

    # shutdown instance
    begin
      bosh_ssh('batlight', instance_id, "sudo reboot", deployment: deployment.name)
    rescue Bosh::Exec::Error
      @logger.debug('Rebooting instance closed the ssh connection')
    end

    wait_for_agent

    # turn on vm resurrection
    bosh('update-resurrection on')
  end

  def wait_for_agent
    # wait for it to come back up (max 2 minutes)
    start = Time.now.to_i
    result = ''
    loop do
      sleep 10
      begin
        result = bosh_ssh('batlight', instance_id, "echo 'UP'", deployment: deployment.name).output
      rescue Bosh::Exec::Error
        @logger.info("Failed to run ssh command. Retrying.")
      end
      break if (Time.now.to_i - start) > 600 || result.include?("UP")
    end

    expect(result).to include("UP")
  end

  def dump_log(ip, log_path)
    @logger.info("Dumping log file '#{log_path}'")
    @logger.info("================================================================================")
    ssh(ip, 'vcap', "([ -f '#{log_path}' ] && cat #{log_path})", ssh_options(@spec))
  end

  def process_running_on_instance(ip, process_name)
    # make sure process is up and running
    tries = 0
    pid = ''
    loop do
      sleep 1
      pid = ssh(ip, 'vcap', "pgrep #{process_name}", ssh_options(@spec))
    rescue Net::SSH::ConnectionTimeout
    ensure
      break if (tries += 1) >= 30 || (pid =~ /^\d+\n$/)
    end

    matched = pid.match(/^\d+\n$/)
    if matched.nil?
      dump_log(ip, "/var/vcap/bosh/log/current")
      dump_log(ip, "/var/vcap/monit/svlog/current")
      dump_log(ip, "/var/vcap/monit/monit.log")
    end
    expect(matched).to_not be_nil, "Expected process '#{process_name}' to be running after 30 seconds, but it was not"
  end

  def runit_running_on_instance(ip)
    process_running_on_instance(ip, "runsvdir")
  end

  def agent_running_on_instance(ip)
    process_running_on_instance(ip, "bosh-agent")
  end

  def monit_running_on_instance(ip)
    process_running_on_instance(ip, "monit")
  end

  def batlight_running_on_instance(ip)
    process_running_on_instance(ip, "batlight")
  end

  let(:bash_functions) do
    <<-EOF
      waitForProcess() {
        local proc_name="${1}"
        local old_pid="${2}"

        for i in `seq 1 30`; do
          new_pid="$(pgrep ^${proc_name}$)"
          if [ -n "${new_pid}" ] && [ "x${old_pid}" != "x${new_pid}" ]; then break; fi
          sleep 1
        done

        if [ -z "${new_pid}" ] || [ "x${old_pid}" = "x${new_pid}" ]; then
          if [ -z "${new_pid}" ]; then
            echo "FAILURE: never found ${proc_name} running"
          else
            echo "FAILURE: ${proc_name} is still running with the prior pid (${old_pid})"
          fi

          exit 1
        fi

        echo $new_pid
      }

      killAndAwaitProcess() {
        local proc_name="${1}"

        local pid="$(waitForProcess ${proc_name})"
        sudo kill -9 ${pid}
        waitForProcess ${proc_name} ${pid}
      }

      waitForSymlink() {
        local name="${1}"
        for i in `seq 1 200`; do
          if [ -h "${name}" ]; then break; fi
          sleep 1
        done

        if [ ! -h "${name}" ]; then
          echo "FAILURE: ${name} missing or not a symlink"
          exit 1
        fi

        readlink ${1}
      }
    EOF
  end

  let(:instance_name) { 'batlight' }
  let(:instance_id) { '0' }

  def srv_cmd
    return service_command('batlight', '0', deployment.name)
  end

  describe 'runit' do
    before(:all) do
      if srv_cmd == "systemctl"
        skip 'Not applicable for agent/monit running on systemd'
      end
    end

    before(:each) do
      runit_running_on_instance(public_ip)
    end

    after(:each) do
      instance_reboot
    end

    context 'when initially started after instance boot (before agent has been started)' do
      it 'deletes /etc/service/monit' do
        # expect /etc/service/monit to be younger that the system's uptime
        cmd = <<-EOF
          #{bash_functions}
          _=$(waitForSymlink /etc/service/monit)
          now="$(date +"%s")"
          mod_time="$(stat --printf="%Y" /etc/service/monit)"
          up_time="$(cut -f1 -d. /proc/uptime)"
          diff=$((${up_time}-${now}+${mod_time}))
          if [ $diff -ge 0 ]; then
            echo "SUCCESS"
          else
            echo "FAILURE: expected /etc/service/monit to be younger than uptime, got a difference of ${diff} seconds"
            exit 1
          fi
        EOF
        expect(ssh(public_ip, 'vcap', cmd, ssh_options(@spec))).to include("SUCCESS\n")
      end

      context 'when monit dies' do
        it 'restarts it' do
          # compare monit pids pre- and post kill
          cmd = <<-EOF
            #{bash_functions}
            old_pid="$(waitForProcess monit-actual "")"
            sudo kill ${old_pid}
            new_pid="$(waitForProcess monit-actual $old_pid)"
            if [[ "${new_pid}" = "${old_pid}" || -z "${new_pid}" ]]; then
              echo "FAILURE"
              exit 1
            fi
            echo "SUCCESS"
          EOF
          output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
          expect(output).to include("SUCCESS")
        end
      end

      context 'when the agent dies' do
        it 'restarts it' do
          # compare agent pids pre- and post kill
          cmd = <<-EOF
            #{bash_functions}
            old_pid="$(waitForProcess bosh-agent "")"
            sudo kill ${old_pid}
            new_pid="$(waitForProcess bosh-agent $old_pid)"
            if [[ "${new_pid}" = "${old_pid}" || -z "${new_pid}" ]]; then
              echo "FAILURE"
              exit 1
            fi
            echo "SUCCESS"
          EOF
          output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
          expect(output).to include("SUCCESS")
        end
      end
    end

    context 'when restarted after agent has been started' do
      it 'does not delete /etc/service/monit' do
        # wait for agent and monit to come up
        agent_running_on_instance(public_ip)
        monit_running_on_instance(public_ip)

        # compare pids pre- and post runsvdir kill
        # make sure runsvdir does not delete /etc/service/monit
        cmd = <<-EOF
          #{bash_functions}
          agent_pid="$(waitForProcess bosh-agent)"
          monit_pid="$(waitForProcess monit-actual)"

          _=$(waitForSymlink /etc/service/monit)
          link_time="$(stat --printf="%Y" /etc/service/monit)"

          _=$(killAndAwaitProcess runsvdir)
          new_agent_pid="$(pgrep ^bosh-agent$)"
          new_monit_pid="$(pgrep ^monit-actual$)"
          if [ "${new_agent_pid}" != "${agent_pid}" ] || [ -z "${new_agent_pid}" ]; then
            echo "FAILURE: Agent pid changed from ${agent_pid} to ${new_agent_pid}"
            exit 1
          fi
          if [ "${new_monit_pid}" != "${monit_pid}" ] || [ -z "${new_monit_pid}" ]; then
            echo "FAILURE: Monit pid changed from ${monit_pid} to ${new_monit_pid}"
            exit 1
          fi
          if [ "$(stat --printf="%Y" /etc/service/monit)" != "${link_time}" ] || [ -z "${link_time}" ]; then
            echo "FAILURE: /etc/service/monit symlink changed"
            exit 1
          fi
          echo "SUCCESS"
        EOF
        output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
        expect(output).to include("SUCCESS")
      end

      context 'when monit dies' do
        it 'restarts it' do
          # wait for monit to come up
          monit_running_on_instance(public_ip)

          # compare monit pids pre- and post kill
          cmd = <<-EOF
            #{bash_functions}
            _=$(killAndAwaitProcess runsvdir)
            _=$(killAndAwaitProcess monit-actual)
            echo "SUCCESS"
          EOF
          output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
          expect(output).to include("SUCCESS")
        end
      end

      context 'when the agent dies' do
        it 'restarts it' do
          # wait for agent to come up
          agent_running_on_instance(public_ip)

          # compare agent pids pre- and post kill
          cmd = <<-EOF
            #{bash_functions}
            _=$(killAndAwaitProcess runsvdir)
            _=$(killAndAwaitProcess bosh-agent)
            echo "SUCCESS"
          EOF
          output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
          expect(output).to include("SUCCESS")
        end
      end
    end
  end

  describe 'systemd' do
    before(:all) do
      if srv_cmd == "sv"
        skip 'Not applicable for agent/monit running on runit'
      end
    end

    after(:each) do
      instance_reboot
    end

    context 'when initially started after instance boot (before agent has been started)' do
      context 'when monit dies' do
        it 'restarts it' do
          # compare monit pids pre- and post kill
          cmd = <<-EOF
            #{bash_functions}
            old_pid="$(waitForProcess monit "")"
            sudo kill ${old_pid}
            new_pid="$(waitForProcess monit $old_pid)"
            if [[ "${new_pid}" = "${old_pid}" || -z "${new_pid}" ]]; then
              echo "FAILURE"
              exit 1
            fi
            echo "SUCCESS"
          EOF
          output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
          expect(output).to include("SUCCESS")
        end
      end

      context 'when the agent dies' do
        it 'restarts it' do
          # compare agent pids pre- and post kill
          cmd = <<-EOF
            #{bash_functions}
            old_pid="$(waitForProcess bosh-agent "")"
            sudo kill ${old_pid}
            new_pid="$(waitForProcess bosh-agent $old_pid)"
            if [[ "${new_pid}" = "${old_pid}" || -z "${new_pid}" ]]; then
              echo "FAILURE"
              exit 1
            fi
            echo "SUCCESS"
          EOF
          output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
          expect(output).to include("SUCCESS")
        end
      end
    end

    context 'when restarted after agent has been started' do
      context 'when monit dies' do
        it 'restarts it' do
          # wait for monit to come up
          monit_running_on_instance(public_ip)

          # compare monit pids pre- and post kill
          cmd = <<-EOF
            #{bash_functions}
            _=$(killAndAwaitProcess monit)
            echo "SUCCESS"
          EOF
          output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
          expect(output).to include("SUCCESS")
        end
      end

      context 'when the agent dies' do
        it 'restarts it' do
          # wait for agent to come up
          agent_running_on_instance(public_ip)

          # compare agent pids pre- and post kill
          cmd = <<-EOF
            #{bash_functions}
            _=$(killAndAwaitProcess bosh-agent)
            echo "SUCCESS"
          EOF
          output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
          expect(output).to include("SUCCESS")
        end
      end
    end
  end

  describe 'agent' do
    before(:each) do
      agent_running_on_instance(public_ip)
    end

    after(:each) do
      wait_for_agent
    end

    context 'when initially started after instance boot' do
      it 'starts monit' do
        # make sure monit is up and running
        monit_running_on_instance(public_ip)
      end

      it 'mounts tmpfs to /var/vcap/data/sys/run' do
        # verify mount point for sys/run
        cmd = "if [ x`mount | grep -c /var/vcap/data/sys/run` = x1 ] ; then echo 'SUCCESS' ; fi"
        expect(ssh(public_ip, 'vcap', cmd, ssh_options(@spec))).to include("SUCCESS\n")
      end

      it 'creates a symlink from /etc/sv/monit to /etc/service/monit' do
        if srv_cmd == "systemctl"
          skip 'Not applicable for agent/monit running on systemd'
        end

        # shutdown agent and remove /etc/service/monit
        # make sure agent recreates /etc/service/monit upon restart
        cmd = <<-EOF
          #{bash_functions}
          sudo PATH=$PATH:/sbin sv down agent
          sudo rm -rf /etc/service/monit
          if [ -f /etc/service/monit ]; then
            echo "FAILURE"
            exit 1
          fi
          sudo PATH=$PATH:/sbin sv up agent
          link_target=$(waitForSymlink /etc/service/monit)
          if [ "${link_target}" != "/etc/sv/monit" ]; then
            echo "FAILURE: wrong symlink for /etc/service/monit: expected /etc/sv/monit, got ${link_target}"
            exit 1
          fi
          echo 'SUCCESS'
        EOF
        output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
        expect(output).to include("SUCCESS")
      end

      it 'does not keep pre-existing pid files in sys/run after instance reboot' do
        # wait until monit comes up
        monit_running_on_instance(public_ip)

        # wait for batlight
        batlight_running_on_instance(public_ip)

        # compare pidfile with actual pid and the pid that monit uses; create dummy file in sys/run
        cmd = <<-EOF
          pgrep=$(pgrep ^batlight$)
          pid=$(cat /var/vcap/data/sys/run/batlight/batlight.pid)
          if [ "${pid}" != "${pgrep}" ]; then
            echo "FAILURE: actual batlight pid (${pgrep}) different from pid in batlight.pid (${pid})"
            exit 1
          fi
          for i in `seq 1 30`; do
            monit=$(sudo monit status | grep "^\s*pid" | awk "{ print \\$2 }")
            if [ -n "${monit}" ] && [ "x${monit}" != "x0" ]; then break; fi
            sleep 1
          done
          if [ "${monit}" != "${pgrep}" ]; then
            echo "FAILURE: actual batlight pid (${pgrep}) different from pid monitored by monit (${monit})"
            exit 1
          fi
          touch /var/vcap/data/sys/run/foo.pid
          echo "SUCCESS"
        EOF
        output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
        expect(output).to include("SUCCESS")

        # reboot instance
        instance_reboot

        # wait for monit
        monit_running_on_instance(public_ip)

        # wait for batlight
        batlight_running_on_instance(public_ip)

        # compare pidfile with actual pid and the pid that monit uses; make sure dummy file in sys/run is gone
        cmd = <<-EOF
          pgrep=$(pgrep ^batlight$)
          pid=$(cat /var/vcap/data/sys/run/batlight/batlight.pid)
          if [ "${pid}" != "${pgrep}" ]; then
            echo "FAILURE: actual batlight pid (${pgrep}) different from pid in batlight.pid (${pid})"
            exit 1
          fi
          for i in `seq 1 30`; do
            monit=$(sudo PATH=$PATH:/var/vcap/bosh/bin monit status | grep "^\s*pid" | awk "{ print \\$2 }")
            if [ -n "${monit}" ] && [ "x${monit}" != "x0" ]; then break; fi
            sleep 1
          done
          if [ "${monit}" != "${pgrep}" ]; then
            echo "FAILURE: actual batlight pid (${pgrep}) different from pid monitored by monit (${monit})"
            exit 1
          fi
          if [ -f /var/vcap/data/sys/run/foo.pid ]; then
            echo "FAILURE: foo.pid still existing"
            exit 1
          fi
          echo "SUCCESS"
        EOF
        output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
        expect(output).to include("SUCCESS")
      end
    end

    context 'when restarted by runit' do
      before(:all) do
        if srv_cmd == "systemctl"
          skip 'Not applicable for agent/monit running on systemd'
        end
      end

      it 'does not remount /var/vcap/data/sys/run' do
        # put file into /var/vcap/data/sys/run
        # restart agent
        # make sure file still exists
        cmd = <<-EOF
          touch /var/vcap/data/sys/run/foo
          sudo PATH=$PATH:/sbin sv down agent
          sudo PATH=$PATH:/sbin sv up agent
          if [ -f /var/vcap/data/sys/run/foo ]; then
            echo "SUCCESS";
          else
            echo "FAILURE: foo not existing anymore"
            exit 1
          fi
        EOF
        output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
        expect(output).to include("SUCCESS")
      end

      it 'does not remove existing pid files' do
        # wait for batlight
        batlight_running_on_instance(public_ip)

        # compare pids pre and post agent restart
        cmd = <<-EOF
          old_pid=$(cat /var/vcap/data/sys/run/batlight/batlight.pid)
          sudo PATH=$PATH:/sbin sv down agent
          sudo PATH=$PATH:/sbin sv up agent
          new_pid=$(cat /var/vcap/data/sys/run/batlight/batlight.pid)
          if [ "${old_pid}" = "${new_pid}" ]; then
            echo "SUCCESS"
          else
            echo "FAILURE: batlight.pid changed"
            exit 1
          fi
        EOF
        output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
        expect(output).to include("SUCCESS")
      end

      it 'does not recreates a symlink from /etc/sv/monit to /etc/service/monit' do
        # compare modification times for /etc/service/monit pre and post agent restart
        cmd = <<-EOF
          old_time=$(stat  --print "%Y" /etc/service/monit)
          sudo PATH=$PATH:/sbin sv down agent
          sudo PATH=$PATH:/sbin sv up agent
          new_time=$(stat  --print "%Y" /etc/service/monit)
          if [ "${old_time}" = "${new_time}" ]; then
            echo "SUCCESS"
          else
            echo "FAILURE: /etc/service/monit modified"
            exit 1
          fi
        EOF
        output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
        expect(output).to include("SUCCESS")
      end

      it 'does not restart monit' do
        # wait for monit
        monit_running_on_instance(public_ip)

        # compare monit pid and process time pre and post agent restart
        cmd = <<-EOF
          old_pid=$(pgrep ^monit-actual$)
          sudo sv down agent
          sudo sv up agent
          new_pid=$(pgrep ^monit-actual$)
          if [ "${old_pid}" = "${new_pid}" ]; then
            echo "SUCCESS"
          else
            echo "FAILURE: monit restarted"
            exit 1
          fi
        EOF
        output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
        expect(output).to include("SUCCESS")
      end
    end

    context 'when restarted by systemd' do
      before(:all) do
        if srv_cmd == "sv"
          skip 'Not applicable for agent/monit running on runit'
        end
      end

      it 'does not remount /var/vcap/data/sys/run' do
        # put file into /var/vcap/data/sys/run
        # restart agent
        # make sure file still exists
        cmd = <<-EOF
          touch /var/vcap/data/sys/run/foo
          sudo PATH=$PATH:/sbin systemctl stop bosh-agent
          sudo PATH=$PATH:/sbin systemctl start bosh-agent
          if [ -f /var/vcap/data/sys/run/foo ]; then
            echo "SUCCESS";
          else
            echo "FAILURE: foo not existing anymore"
            exit 1
          fi
        EOF
        output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
        expect(output).to include("SUCCESS")
      end

      it 'does not remove existing pid files' do
        # wait for batlight
        batlight_running_on_instance(public_ip)

        # compare pids pre and post agent restart
        cmd = <<-EOF
          old_pid=$(cat /var/vcap/data/sys/run/batlight/batlight.pid)
          sudo PATH=$PATH:/sbin systemctl stop bosh-agent
          sudo PATH=$PATH:/sbin systemctl start bosh-agent
          new_pid=$(cat /var/vcap/data/sys/run/batlight/batlight.pid)
          if [ "${old_pid}" = "${new_pid}" ]; then
            echo "SUCCESS"
          else
            echo "FAILURE: batlight.pid changed"
            exit 1
          fi
        EOF
        output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
        expect(output).to include("SUCCESS")
      end

      it 'does not restart monit' do
        # wait for monit
        monit_running_on_instance(public_ip)

        # compare monit pid and process time pre and post agent restart
        cmd = <<-EOF
          old_pid=$(pgrep ^monit$)
          sudo systemctl stop bosh-agent
          sudo systemctl start bosh-agent
          new_pid=$(pgrep ^monit$)
          if [ "${old_pid}" = "${new_pid}" ]; then
            echo "SUCCESS"
          else
            echo "FAILURE: monit restarted"
            exit 1
          fi
        EOF
        output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
        expect(output).to include("SUCCESS")
      end
    end
  end

  describe 'monit' do
    before(:each) do
      # wait for monit to come up
      monit_running_on_instance(public_ip)
    end

    context 'when initially started by agent' do
      context 'when a monitored process dies' do
        it 'restarts it' do
          # wait for batlight
          batlight_running_on_instance(public_ip)

          # kill batlight
          cmd = "sudo pkill batlight && echo 'SUCCESS'"
          output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
          expect(output).to include("SUCCESS")

          # wait for batlight to come up again
          batlight_running_on_instance(public_ip)
        end
      end
    end

    context 'when restarted by runit/systemd' do
      context 'when a monitored process dies' do
        it 'restarts it' do
          # kill monit
          cmd = "sudo pkill monit && echo 'SUCCESS'"
          output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
          expect(output).to include("SUCCESS")

          # wait for monit to come up again
          monit_running_on_instance(public_ip)

          # kill batlight
          cmd = "sudo pkill batlight && echo 'SUCCESS'"
          output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
          expect(output).to include("SUCCESS")

          # wait for batlight to come up again
          batlight_running_on_instance(public_ip)
        end
      end

      context 'when monit is running' do
        it 'can not be reached from the host' do
          cmd = 'sudo -- netstat -ntpl | grep monit | awk "{print $4}" | xargs curl -m1'
          output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name, on_error: :return).output
          expect(output).to include("Connection timed out")
        end

        context 'when using the monit cli' do
          it 'can reach the api and show a summary' do
            cmd = "sudo monit summary && echo 'SUCCESS'"
            output = bosh_ssh(instance_name, instance_id, cmd, deployment: deployment.name).output
            expect(output).to include("SUCCESS")
          end
        end
      end
    end
  end
end
