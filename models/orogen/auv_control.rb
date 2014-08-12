require 'models/blueprints/auv'
    
module Base
    data_service_type 'WorldXYZRollPitchYawControlledSystemSrv' do
       input_port 'world_cmd', 'base/LinearAngular6DCommand'
    end

    data_service_type 'WorldZRollPitchYawSrv' do
       input_port 'world_cmd', '/base/LinearAngular6DCommand'
       input_port 'Velocity_cmd', '/base/LinearAngular6DCommand'
    end

    #Base::ControlLoop.declare 'WorldXYZRollPitchYaw', Auv::WorldZRollPitchYawSrvVelocityXY
    #Base::ControlLoop.declare 'WorldXYZRollPitchYaw', '/base/LinearAngular6DCommand'
    #Base::ControlLoop.declare 'WorldZRollPitchYaw', '/base/LinearAngular6DCommand'
    #Base::ControlLoop.declare 'XYVelocity', '/base/LinearAngular6DCommand'
end

class AuvControl::ConstantCommand
    attr_reader :options

    def configure
        super
        return if(!@options)
        update_config(@options)
    end

    def update_config(options)
        @options = options

        STDOUT.puts "Starting real Poisitioning task with options: #{@options}"
        cmd = orocos_task.cmd
        cmd.linear[0] = @options[:x];
        cmd.linear[1] = @options[:y];
        cmd.linear[2] = @options[:depth];

        cmd.angular[0] = 0;
        cmd.angular[1] = 0;
        cmd.angular[2] = @options[:heading];
        orocos_task.cmd = cmd
        #constand_command_world.configure

    end

#    provides Base::WorldXYZRollPitchYawControllerSrv, :as => 'world_cmd'
end
