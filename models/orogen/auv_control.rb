require 'models/blueprints/auv'
using_task_library 'auv_control'
    
module ::Base
    data_service_type 'WorldXYZRollPitchYawControlledSystemSrv' do
       input_port 'world_cmd', '/base/LinearAngular6DCommand'
    end

    data_service_type 'WorldXYZRollPitchYawControllerSrv' do
       output_port 'world_cmd', '/base/LinearAngular6DCommand'
    end

    data_service_type 'WorldXYPositionControllerSrv' do
       output_port 'world_command', '/base/LinearAngular6DCommand'
       output_port 'aligned_position_command', '/base/LinearAngular6DCommand'
    end

    data_service_type 'WorldXYZPositionControllerSrv' do
       output_port 'world_command', '/base/LinearAngular6DCommand'
       output_port 'aligned_position_command', '/base/LinearAngular6DCommand'
    end

    data_service_type 'WorldYPositionXVelocityControllerSrv' do
       output_port 'world_command', '/base/LinearAngular6DCommand'
       output_port 'aligned_position_command', '/base/LinearAngular6DCommand'
       output_port 'aligned_velocity_command', '/base/LinearAngular6DCommand'
    end

    data_service_type 'WorldXYVelocityControllerSrv' do
       output_port 'world_command', '/base/LinearAngular6DCommand'
       output_port 'aligned_velocity_command', '/base/LinearAngular6DCommand'
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

        cmd = orocos_task.cmd
        cmd.linear[0]  = NaN
        cmd.linear[1]  = NaN
        cmd.linear[2]  = NaN
        cmd.angular[0] = NaN
        cmd.angular[1] = NaN
        cmd.angular[2] = NaN

        cmd.linear[0] = @options[:x] if @options[:x]
        cmd.linear[1] = @options[:y] if @options[:y]
        cmd.linear[2] = @options[:depth] if @options[:depth]

        cmd.angular[0] = @options[:roll] if @options[:roll] 
        cmd.angular[1] = @options[:pitch] if @options[:pitch]
        cmd.angular[2] = @options[:heading] if @options[:heading]
        orocos_task.cmd = cmd
        #constant_command_world.configure

    end
       # provides Base::WorldXYZRollPitchYawControllerSrv , :as => "world_controller"

    provides Base::WorldXYZRollPitchYawControllerSrv, :as => 'world_cmd'
end

class ConsWA < Syskit::Composition
    add AuvControl::ConstantCommand, :as => 'controller_v'
    controller_v_child.prefer_deployed_tasks "constant_command_vel"
    export controller_v_child.cmd_out_port
    controller_v_child.with_conf('dummy2')
    def update_config(options)
        controller_v_child.update_config(:x => options[:x], :y => options[:y])
    end
end

class ConstantWorldXYVelocityCommand < Syskit::Composition
    add AuvControl::ConstantCommand, :as => 'controller_w'
    controller_w_child.prefer_deployed_tasks "constant_command"
    controller_w_child.with_conf('dummy1')
    add ConsWA, as: 'controller_v' 
    export controller_w_child.cmd_out_port, as: 'world_command'
    export controller_v_child.cmd_out_port, as: 'aligned_velocity_command'
    provides Base::WorldXYVelocityControllerSrv, as: 'controller'
                
    
    def update_config(options)
        controller_w_child.update_config(:heading => options[:heading], :depth => options[:depth], :pitch => 0, :roll => 0)
        controller_v_child.update_config(:x => options[:x], :y => options[:y])
    end
    
end

