module Dev
#    device_type "ExperimentMarkers" do
#        provides Dev::Bus::CAN::ClientInSrv
#    end
    device_type "SystemStatus" do
        provides Dev::Bus::CAN::ClientInSrv
    end
end

class Sysmon::Task
#    driver_for Dev::ExperimentMarkers, :as => "marker", "from_bus" => "can_in_experiment_markers"
    driver_for Dev::SystemStatus, :as => "system_status", "from_bus" => "can_in_system_status"

    on :start do |event|
        @system_status = data_reader :system_status
        ::State.lowlevel_substate = 0 
    end

    poll do
        if !@system_status.nil?
            if sample = @system_status.read
                ::State.lowlevel_state = sample.systemState
	        ::State.lowlevel_substate = sample.systemSubstate
            end
        end
    end
end

