=begin
require 'models/blueprints/localization'
using_task_library 'modemdriver'
using_task_library 'modem_position'
module Modem
    class ModemCmp < Syskit::Composition
        add_main ::Modemdriver::ModemCanbus, as: 'main'
        add ModemPosition::ModemPositionSender, as: 'producer'
        add Base::PoseSrv, as: 'pose'

        connect pose_child.pose_samples_port => producer_child
        connect producer_child => main_child


        argument :timeout, :default => 60

        on :start do |e|
                @start_time = Time.now
                Robot.info "Shouting to ASV"
        end

        poll do
            @start_time = Time.now if @start_time.nil?
            if @start_time.my_timeout?(timeout)
                Robot.info  "Timeout! #{@start_time} #{@start_time + timeout}"
                emit :success 
            end
        end

    end
end
=end
