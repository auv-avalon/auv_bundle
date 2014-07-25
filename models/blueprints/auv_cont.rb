require 'rock/models/blueprints/control'
require "models/blueprints/control"
require "models/blueprints/localization"
require "models/blueprints/avalon"
using_task_library 'auv_control'
module AuvCont
    #WORLD_TO_ALIGNED
    #data_service_type 'WorldXYZRollPitchYawSrv' do
    #    input_port 'world_cmd', 'base/LinearAngular6DCommand'
    #end
    data_service_type 'WorldZRollPitchYawSrvVelocityXY' do
        input_port 'world_cmd', 'base/LinearAngular6DCommand'
        input_port 'Velocity_cmd', 'base/LinearAngular6DCommand'
    end
   
    class WorldPositionCmp < Syskit::Composition
        add ::Base::JointsCommandConsumerSrv, :as => "joint"
        add ::Base::PoseSrv, :as => "pose"
        add AuvControl::WorldToAligned.with_conf("default"), :as => "world_to_aligned"
        add AuvControl::OptimalHeadingController.with_conf("default"), :as => "optimal_heading_controller"
        add AuvControl::PIDController.prefer_deployed_tasks("aligned_position_controller"), :as => "aligned_position_controller"
        add AuvControl::PIDController.prefer_deployed_tasks("aligned_velocity_controller"), :as => "aligned_velocity_controller"
        add AuvControl::AlignedToBody, :as => "aligned_to_body"
        add AuvControl::AccelerationController, :as => "controller"
        
        conf 'simulation', 'aligned_position_controller' => ['default', 'position_simulation_parallel'],
                           'aligned_velocity_controller' => ['default', 'velocity_simulation_parallel'],
                           'controller' => ['default_simulation']
        conf 'default', 'aligned_position_controller' => ['default', 'position'],
                           'aligned_velocity_controller' => ['default', 'velocity'],
                           'controller' => ['default']
        pose_child.connect_to world_to_aligned_child
        pose_child.connect_to aligned_position_controller_child
        pose_child.connect_to aligned_velocity_controller_child
        pose_child.connect_to aligned_to_body_child
        pose_child.connect_to optimal_heading_controller_child
        world_to_aligned_child.cmd_out_port.connect_to optimal_heading_controller_child.cmd_cascade_port
        optimal_heading_controller_child.cmd_out_port.connect_to aligned_position_controller_child.cmd_cascade_port
        aligned_position_controller_child.cmd_out_port.connect_to aligned_velocity_controller_child.cmd_cascade_port
        aligned_velocity_controller_child.cmd_out_port.connect_to aligned_to_body_child.cmd_cascade_port
        aligned_to_body_child.cmd_out_port.connect_to controller_child.cmd_cascade_port
        controller_child.connect_to joint_child
        
        export world_to_aligned_child.cmd_in_port
        export controller_child.cmd_out_port
        provides ::Base::WorldXYZRollPitchYawControlledSystemSrv, :as => "cmd_in"

        #TODO @Christian, wenn du hier "nur" ein CommandSrv definierst erfüllt das den controlloop ja nicht, das meinte ich schonmal
        #provides ::Base::JointsControllerSrv, :as => "command_out"
        provides ::Base::JointsCommandSrv, :as => "command_out"

    end
    class WorldAndXYVelocityCmp < Syskit::Composition
        add ::Base::JointsCommandConsumerSrv, :as => "joint"
        add ::Base::PoseSrv, :as => "pose"
        add AuvControl::WorldToAligned.with_conf("default"), :as => "world_to_aligned"
        add AuvControl::OptimalHeadingController.with_conf("default"), :as => "optimal_heading_controller"
        add AuvControl::PIDController.prefer_deployed_tasks("aligned_position_controller"), :as => "aligned_position_controller"
        add AuvControl::PIDController.prefer_deployed_tasks("aligned_velocity_controller"), :as => "aligned_velocity_controller"
        add AuvControl::AlignedToBody, :as => "aligned_to_body"
        add AuvControl::AccelerationController, :as => "controller"
        
        conf 'simulation', 'aligned_position_controller' => ['default', 'position_simulation_parallel'],
                           'aligned_velocity_controller' => ['default', 'velocity_simulation_parallel'],
                           'controller' => ['default_simulation']
        conf 'default', 'aligned_position_controller' => ['default', 'position'],
                           'aligned_velocity_controller' => ['default', 'velocity'],
                           'controller' => ['default']
        pose_child.connect_to world_to_aligned_child
        pose_child.connect_to aligned_position_controller_child
        pose_child.connect_to aligned_velocity_controller_child
        pose_child.connect_to aligned_to_body_child
        pose_child.connect_to optimal_heading_controller_child
        world_to_aligned_child.cmd_out_port.connect_to optimal_heading_controller_child.cmd_cascade_port
        optimal_heading_controller_child.cmd_out_port.connect_to aligned_position_controller_child.cmd_cascade_port
        aligned_position_controller_child.cmd_out_port.connect_to aligned_velocity_controller_child.cmd_cascade_port
        aligned_velocity_controller_child.cmd_out_port.connect_to aligned_to_body_child.cmd_cascade_port
        aligned_to_body_child.cmd_out_port.connect_to controller_child.cmd_cascade_port
        controller_child.connect_to joint_child
        
        export world_to_aligned_child.cmd_in_port, :as => 'world_in'
        export aligned_velocity_controller_child.cmd_in_port, :as => 'velocity_in'
        export controller_child.cmd_out_port
        provides ::Base::WorldZRollPitchYawControlledSystemSrv, :as => "world_in_s", "command_in" => "velocity_in"
        provides ::Base::XYVelocityControlledSystemSrv, :as => "velocity_in_s", "command_in" => "world_in"
        provides ::Base::JointsCommandSrv, :as => "command_out"
    end
    
    ::Base::ControlLoop.specialize ::Base::ControlLoop.controller_child => WorldPositionCmp
    ::Base::ControlLoop.specialize ::Base::ControlLoop.controller_child => WorldAndXYVelocityCmp
=begin
    class WorldZRollPitchYawVelocityXY < ::Base::ControlLoop
        add ::Base::JointsCommandConsumerSrv, :as => "joint_srv"
        add ::Localization::ParticleDetector, :as => "pose"
        add AuvCont::WorldToAligned.with_conf("default","ZRollPitchYaw"), :as => "world_to_aligned"
        add AuvCont::PIDController.with_conf("default","aligned","position","ZRollPitchYaw"), :as => "aligned_position_controller"
        add AuvCont::PIDController.with_conf("default","aligned","velocity","all"), :as => "aligned_velocity_controller"
        add AuvCont::AlignedToBody, :as => "aligned_to_body"
        add AuvCont::AccelerationController, :as => "acceleration_controller"
        
        pose_child.connect_to world_to_aligned_child
        pose_child.connect_to aligned_position_controller_child
        pose_child.connect_to aligned_velocity_controller_child
        pose_child.connect_to aligned_to_body_child
        world_to_aligned_child.cmd_out_port.connect_to aligned_position_controller_child.cmd_cascade_port
        aligned_position_controller_child.cmd_out_port.connect_to aligned_velocity_controller_child.cmd_cascade_port
        aligned_velocity_controller_child.cmd_out_port.connect_to aligned_to_body_child.cmd_cascade_port
        aligned_to_body_child.cmd_out_port.connect_to acceleration_controller_child.cmd_cascade_port
        acceleration_controller_child.cmd_out_port.connect_to joint_srv_child 
        
        export world_to_aligned_child.cmd_in_port
        export aligned_velocity_controller_child.cmd_in_port
        provides WorldZRollPitchYawSrvVelocityXY, :as => "cmd_in"
        
    end
=end
end
    

