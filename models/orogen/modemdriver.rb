module Dev
    device_type "ASVModem" do
        provides Dev::Bus::CAN::ClientOutSrv
    end
end

class Modemdriver::ModemCanbus 
    driver_for Dev::ASVModem, :as => "foo"#, "from_bus" => "can_in_system_status"
end

