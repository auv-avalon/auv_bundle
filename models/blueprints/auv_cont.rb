require 'rock/models/blueprints/control'
require "models/blueprints/control"
require "models/blueprints/localization"
require "models/blueprints/auv"

using_task_library 'auv_control'

module AuvCont

    DELTA_YAW = 0.1
    DELTA_Z = 100
    DELTA_XY = 2
    DELTA_TIMEOUT = 2

    #WORLD_TO_ALIGNED
    #data_service_type 'WorldXYZRollPitchYawSrv' do
    #    input_port 'world_cmd', 'base/LinearAngular6DCommand'
    #end
#    data_service_type 'WorldZRollPitchYawSrvVelocityXY' do
#        input_port 'world_cmd', 'base/LinearAngular6DCommand'
#        input_port 'Velocity_cmd', 'base/LinearAngular6DCommand'
#    end
    

    class ConstantCommandGroundAvoidanceCmp < Syskit::Composition
        add AuvControl::ConstantCommandGroundAvoidance.with_conf("avoid"), as: 'main'
        add Base::GroundDistanceSrv, as: 'altimeter'
        add Base::ZProviderSrv, as: 'depth'

        connect altimeter_child => main_child.altimeter_port
        connect depth_child => main_child.depth_port

        export main_child.cmd_out_port
        export main_child.cmd_in_port
    end
   
    class WorldPositionCmp < Syskit::Composition
        add ::Base::JointsControlledSystemSrv, :as => "joint"
        add ::Base::PoseSrv, :as => "pose"
        add AuvCont::ConstantCommandGroundAvoidanceCmp, :as => 'avoid'
        add AuvControl::WorldToAligned.with_conf("default"), :as => "world_to_aligned"
        add AuvControl::OptimalHeadingController.with_conf("default"), :as => "optimal_heading_controller"
        add AuvControl::PIDController.prefer_deployed_tasks("aligned_position_controller"), :as => "aligned_position_controller"
        add AuvControl::PIDController.prefer_deployed_tasks("aligned_velocity_controller"), :as => "aligned_velocity_controller"
        add AuvControl::AlignedToBody, :as => "aligned_to_body"
        add AuvControl::AccelerationController, :as => "acceleration_controller"

        if ::CONFIG_HACK == 'default'
            aligned_position_controller_child.prefer_deployed_tasks("aligned_position_controller").with_conf("default", 'position_parallel')
        elsif ::CONFIG_HACK == 'simulation'
            aligned_position_controller_child.prefer_deployed_tasks("aligned_position_controller").with_conf("default", 'position_simulation_parallel')
        elsif ::CONFIG_HACK == 'dagon'
            aligned_position_controller_child.prefer_deployed_tasks("aligned_position_controller").with_conf("default_aligned_position")
        end

        add AuvControl::PIDController, :as => "aligned_velocity_controller"
        if  ::CONFIG_HACK == 'default'
            aligned_velocity_controller_child.prefer_deployed_tasks("aligned_velocity_controller").with_conf("dummy", 'velocity_parallel')
        elsif ::CONFIG_HACK == 'simulation'
            aligned_velocity_controller_child.prefer_deployed_tasks("aligned_velocity_controller").with_conf("dummy", 'velocity_simulation_parallel')
        elsif ::CONFIG_HACK == 'dagon'
            aligned_velocity_controller_child.prefer_deployed_tasks("aligned_velocity_controller").with_conf("default_aligned_velocity")
        end

        add AuvControl::AccelerationController, :as => "acceleration_controller"
        if  ::CONFIG_HACK == 'default'
            acceleration_controller_child.with_conf("default")
        elsif ::CONFIG_HACK == 'simulation'
            acceleration_controller_child.with_conf("default_simulation")
        elsif ::CONFIG_HACK == 'dagon'
            acceleration_controller_child.with_conf('default', 'all_thruster_huelle')
        end
        add Base::WorldXYZRollPitchYawControllerSrv, :as => "controller"
        
        #conf 'simulation', 'aligned_position_controller' => ['default', 'position_simulation_parallel'],
        #                   'aligned_velocity_controller' => ['default', 'velocity_simulation_parallel'],
        #                   'acceleration_controller' => ['default_simulation']
        #conf 'default', 'aligned_position_controller' => ['default', 'position'],
        #                   'aligned_velocity_controller' => ['default', 'velocity'],
        #                   'acceleration_controller' => ['default']
        #
        #connect controller_child.world_cmd_port => world_to_aligned_child.cmd_in_port
        connect controller_child.world_cmd_port => avoid_child.cmd_in_port
        connect avoid_child => world_to_aligned_child.cmd_in_port
        pose_child.connect_to world_to_aligned_child
        pose_child.connect_to aligned_position_controller_child
        pose_child.connect_to aligned_velocity_controller_child
        pose_child.connect_to aligned_to_body_child
        pose_child.connect_to optimal_heading_controller_child
        world_to_aligned_child.cmd_out_port.connect_to optimal_heading_controller_child.cmd_cascade_port
        optimal_heading_controller_child.cmd_out_port.connect_to aligned_position_controller_child.cmd_cascade_port
        aligned_position_controller_child.cmd_out_port.connect_to aligned_velocity_controller_child.cmd_cascade_port
        aligned_velocity_controller_child.cmd_out_port.connect_to aligned_to_body_child.cmd_cascade_port
        aligned_to_body_child.cmd_out_port.connect_to acceleration_controller_child.cmd_cascade_port
        acceleration_controller_child.connect_to joint_child
        
        export world_to_aligned_child.cmd_in_port
        export acceleration_controller_child.cmd_out_port
        provides ::Base::WorldXYZRollPitchYawControlledSystemSrv, :as => "cmd_in"

        #provides ::Base::JointsControllerSrv, :as => "command_out"
        provides ::Base::JointsCommandSrv, :as => "command_out"

        event :reached_target
        event :servoing_finished
        event :not_enough_targets

        on :start do |event|
            if controller_child.respond_to? 'reached_target_event'
                controller_child.reached_target_event.forward_to reached_target_event
            end
            
            if controller_child.respond_to? 'servoing_finished_event'
              controller_child.servoing_finished_event.forward_to servoing_finished_event
            end
            
            if controller_child.respond_to? 'not_enough_targets_event'
              controller_child.not_enough_targets_event.forward_to not_enough_targets_event
            end
            
        end

    end
    class WorldXYVelocityCmp < Syskit::Composition

        add ::Base::JointsControlledSystemSrv, :as => "joint"
        add ::Base::PoseSrv, :as => "pose"
        add AuvCont::ConstantCommandGroundAvoidanceCmp, :as => 'avoid'
        add AuvControl::WorldToAligned.with_conf('default', 'no_xy'), :as => "world_to_aligned"
        add AuvControl::OptimalHeadingController.with_conf('default', 'no_xy'), :as => "optimal_heading_controller"
        #add AuvControl::PIDController.prefer_deployed_tasks("aligned_position_controller"), :as => "aligned_position_controller"
        #add AuvControl::PIDController.prefer_deployed_tasks("aligned_velocity_controller"), :as => "aligned_velocity_controller"
        add AuvControl::PIDController, :as => "aligned_position_controller"

        if ::CONFIG_HACK == 'default'
            aligned_position_controller_child.prefer_deployed_tasks("aligned_position_controller").with_conf("default", 'position_parallel', 'no_xy')
        elsif ::CONFIG_HACK == 'simulation'
            aligned_position_controller_child.prefer_deployed_tasks("aligned_position_controller").with_conf("default", 'position_simulation_parallel', 'no_xy')
        elsif ::CONFIG_HACK == 'dagon'
            aligned_position_controller_child.prefer_deployed_tasks("aligned_position_controller").with_conf('default_aligned_position', 'no_xy')
        end

        add AuvControl::PIDController, :as => "aligned_velocity_controller"
        if  ::CONFIG_HACK == 'default'
            aligned_velocity_controller_child.prefer_deployed_tasks("aligned_velocity_controller").with_conf("dummy", 'velocity_parallel')
        elsif ::CONFIG_HACK == 'simulation'
            aligned_velocity_controller_child.prefer_deployed_tasks("aligned_velocity_controller").with_conf("dummy", 'velocity_simulation_parallel')
        elsif ::CONFIG_HACK == 'dagon'
            aligned_velocity_controller_child.prefer_deployed_tasks("aligned_velocity_controller").with_conf("default_aligned_velocity")
        end

        add AuvControl::AccelerationController, :as => "acceleration_controller"
        if  ::CONFIG_HACK == 'default'
            acceleration_controller_child.with_conf('default')
        elsif ::CONFIG_HACK == 'simulation'
            acceleration_controller_child.with_conf("default_simulation")
        elsif ::CONFIG_HACK == 'dagon'
            acceleration_controller_child.with_conf('default', 'all_thruster_huelle')
        end
        add AuvControl::AlignedToBody, :as => "aligned_to_body"
        add Base::WorldXYVelocityControllerSrv, :as => "controller"
#        command_child.prefer_deployed_tasks("constant_command")
        
        #conf 'simulation',
        #conf 'simulation', 'aligned_position_controller' => ['position_simulation_parallel'],
        #                   'aligned_velocity_controller' => ['default', 'velocity_simulation_parallel'],
        #                   'acceleration_controller' => ['default_simulation']
        #conf 'default',
        #conf 'default', 'aligned_position_controller' => ['default', 'position'],
        #                   'aligned_velocity_controller' => ['default', 'velocity'],
        #                   'acceleration_controller' => ['default', 'all_thruster_huelle']

#        command_child.connect_to world_to_aligned_child.cmd_in_port

        #connect controller_child.world_command_port => world_to_aligned_child.cmd_in_port
        connect controller_child.world_command_port => avoid_child
        connect avoid_child => world_to_aligned_child.cmd_in_port
        connect controller_child.aligned_velocity_command_port => aligned_velocity_controller_child.cmd_in_port
        connect pose_child => world_to_aligned_child
        connect pose_child => aligned_position_controller_child
        connect pose_child => aligned_velocity_controller_child
        connect pose_child => aligned_to_body_child
        connect pose_child => optimal_heading_controller_child
        connect world_to_aligned_child.cmd_out_port => optimal_heading_controller_child.cmd_cascade_port
        connect optimal_heading_controller_child.cmd_out_port => aligned_position_controller_child.cmd_cascade_port
        connect aligned_position_controller_child.cmd_out_port => aligned_velocity_controller_child.cmd_cascade_port
        connect aligned_velocity_controller_child.cmd_out_port => aligned_to_body_child.cmd_cascade_port
        connect aligned_to_body_child.cmd_out_port => acceleration_controller_child.cmd_cascade_port
        connect acceleration_controller_child => joint_child
        
        export world_to_aligned_child.cmd_in_port, :as => 'world_in'
        export aligned_velocity_controller_child.cmd_in_port, :as => 'velocity_in'
        export acceleration_controller_child.cmd_out_port
    #    provides ::Base::WorldZRollPitchYawControlledSystemSrv, :as => "world_in_s", "command_in" => "velocity_in"
    #    provides ::Base::XYVelocityControlledSystemSrv, :as => "velocity_in_s", "command_in" => "world_in"
        #provides ::WorldXYZRollPitchYawControlledSystemSrv, :as => 'controlled_system'
        provides ::Base::JointsCommandSrv, :as => "command_out"
#        event :aligned
 #       event :aligning

#         on :start do |e|
#                controller_child.aligning_event.forward_to aligning_event
#                controller_child.aligned_event.forward_to aligned_event
#         end
    end
    
    class WorldXYPositionCmp < Syskit::Composition

        add ::Base::JointsControlledSystemSrv, :as => "joint"
        add ::Base::PoseSrv, :as => "pose"
        add AuvCont::ConstantCommandGroundAvoidanceCmp, :as => 'avoid'
        add AuvControl::WorldToAligned.with_conf('default', 'no_xy'), :as => "world_to_aligned"
        add AuvControl::OptimalHeadingController.with_conf('default', 'no_xy'), :as => "optimal_heading_controller"
        #add AuvControl::PIDController.prefer_deployed_tasks("aligned_position_controller"), :as => "aligned_position_controller"
        #add AuvControl::PIDController.prefer_deployed_tasks("aligned_velocity_controller"), :as => "aligned_velocity_controller"
        add AuvControl::PIDController, :as => "aligned_position_controller"

        if ::CONFIG_HACK == 'default'
            aligned_position_controller_child.prefer_deployed_tasks("aligned_position_controller").with_conf("default", 'position_parallel')
        elsif ::CONFIG_HACK == 'simulation'
            aligned_position_controller_child.prefer_deployed_tasks("aligned_position_controller").with_conf("default", 'position_simulation_parallel')
        elsif ::CONFIG_HACK == 'dagon'
            aligned_position_controller_child.prefer_deployed_tasks("aligned_position_controller").with_conf('default_aligned_position')
        end

        add AuvControl::PIDController, :as => "aligned_velocity_controller"
        if  ::CONFIG_HACK == 'default'
            aligned_velocity_controller_child.prefer_deployed_tasks("aligned_velocity_controller").with_conf("dummy", 'velocity_parallel')
        elsif ::CONFIG_HACK == 'simulation'
            aligned_velocity_controller_child.prefer_deployed_tasks("aligned_velocity_controller").with_conf("dummy", 'velocity_simulation_parallel')
        elsif ::CONFIG_HACK == 'dagon'
            aligned_velocity_controller_child.prefer_deployed_tasks("aligned_velocity_controller").with_conf("default_aligned_velocity")
        end

        add AuvControl::AccelerationController, :as => "acceleration_controller"
        if  ::CONFIG_HACK == 'default'
            acceleration_controller_child.with_conf("default")
        elsif ::CONFIG_HACK == 'simulation'
            acceleration_controller_child.with_conf("default_simulation")
        elsif ::CONFIG_HACK == 'dagon'
            acceleration_controller_child.with_conf('default', 'all_thruster_huelle')
        end
        add AuvControl::AlignedToBody, :as => "aligned_to_body"
        add_main ::Base::WorldXYPositionControllerSrv, :as => 'controller'
#        add Base::WorldXYZRollPitchYawControllerSrv, :as => "command"
#        command_child.prefer_deployed_tasks("constant_command")
        
        #conf 'simulation',
        #conf 'simulation', 'aligned_position_controller' => ['position_simulation_parallel'],
        #                   'aligned_velocity_controller' => ['default', 'velocity_simulation_parallel'],
        #                   'acceleration_controller' => ['default_simulation']
        #conf 'default',
        #conf 'default', 'aligned_position_controller' => ['default', 'position'],
        #                   'aligned_velocity_controller' => ['default', 'velocity'],
        #                   'acceleration_controller' => ['default', 'all_thruster_huelle']

#        command_child.connect_to world_to_aligned_child.cmd_in_port
        
        argument :timeout, :default => nil
        argument :corners, :default => nil


        #connect controller_child.world_command_port => world_to_aligned_child.cmd_in_port
        connect controller_child.world_command_port => avoid_child
        connect avoid_child => world_to_aligned_child.cmd_in_port
        connect controller_child.aligned_position_command_port => aligned_position_controller_child.cmd_in_port

        pose_child.connect_to world_to_aligned_child
        pose_child.connect_to aligned_position_controller_child
        pose_child.connect_to aligned_velocity_controller_child
        pose_child.connect_to aligned_to_body_child
        pose_child.connect_to optimal_heading_controller_child
        world_to_aligned_child.cmd_out_port.connect_to optimal_heading_controller_child.cmd_cascade_port
        optimal_heading_controller_child.cmd_out_port.connect_to aligned_position_controller_child.cmd_cascade_port
        aligned_position_controller_child.cmd_out_port.connect_to aligned_velocity_controller_child.cmd_cascade_port
        aligned_velocity_controller_child.cmd_out_port.connect_to aligned_to_body_child.cmd_cascade_port
        aligned_to_body_child.cmd_out_port.connect_to acceleration_controller_child.cmd_cascade_port
        acceleration_controller_child.connect_to joint_child
        
        export world_to_aligned_child.cmd_in_port, :as => 'world_in'
        export aligned_velocity_controller_child.cmd_in_port, :as => 'velocity_in'
        export acceleration_controller_child.cmd_out_port
    #    provides ::Base::WorldZRollPitchYawControlledSystemSrv, :as => "world_in_s", "command_in" => "velocity_in"
    #    provides ::Base::XYVelocityControlledSystemSrv, :as => "velocity_in_s", "command_in" => "world_in"
        #provides ::WorldXYZRollPitchYawControlledSystemSrv, :as => 'controlled_system'
        provides ::Base::JointsCommandSrv, :as => "command_out"

        event :detected_corner
#
        on :start do |ev|
                controller_child.success_event.forward_to success_event
                @start_time = Time.now
                @num_corners = 0 
                Robot.info "Starting Position moving #{self}"
        end

        def corner_passed!
            @num_corners = @num_corners + 1 
        end

        on :detected_corner do |e|
            self.corner_passed!
            Robot.info "Passed a corner, have passed #{@num_corners}"
        end

        poll do
            @start_time = Time.now if @start_time.nil?
            if @start_time.my_timeout?(timeout)
                Robot.info  "Timeout! #{@start_time} #{@start_time + timeout}"
                emit :success 
            end
            if(self.corners)
                if(@num_corners == self.corners)
                    Robot.info "Wall servoing succssfull get all #{self.corners} corners"
                    emit :success
                end
            end
        end
    end

    class WorldXYZPositionCmp < Syskit::Composition

        add ::Base::JointsControlledSystemSrv, :as => "joint"
        add ::Base::PoseSrv, :as => "pose"
        add AuvControl::WorldToAligned.with_conf('default', 'no_xyz'), :as => "world_to_aligned"
        add AuvControl::OptimalHeadingController.with_conf('default', 'no_xyz'), :as => "optimal_heading_controller"
        #add AuvControl::PIDController.prefer_deployed_tasks("aligned_position_controller"), :as => "aligned_position_controller"
        #add AuvControl::PIDController.prefer_deployed_tasks("aligned_velocity_controller"), :as => "aligned_velocity_controller"
        add AuvControl::PIDController, :as => "aligned_position_controller"

        if ::CONFIG_HACK == 'default'
            aligned_position_controller_child.prefer_deployed_tasks("aligned_position_controller").with_conf("default", 'position_parallel')
        elsif ::CONFIG_HACK == 'simulation'
            aligned_position_controller_child.prefer_deployed_tasks("aligned_position_controller").with_conf("default", 'position_simulation_parallel')
        elsif ::CONFIG_HACK == 'dagon'
            aligned_position_controller_child.prefer_deployed_tasks("aligned_position_controller").with_conf('default_aligned_position')
        end

        add AuvControl::PIDController, :as => "aligned_velocity_controller"
        if  ::CONFIG_HACK == 'default'
            aligned_velocity_controller_child.prefer_deployed_tasks("aligned_velocity_controller").with_conf("dummy", 'velocity_parallel')
        elsif ::CONFIG_HACK == 'simulation'
            aligned_velocity_controller_child.prefer_deployed_tasks("aligned_velocity_controller").with_conf("dummy", 'velocity_simulation_parallel')
        elsif ::CONFIG_HACK == 'dagon'
            aligned_velocity_controller_child.prefer_deployed_tasks("aligned_velocity_controller").with_conf("default_aligned_velocity")
        end

        add AuvControl::AccelerationController, :as => "acceleration_controller"
        if  ::CONFIG_HACK == 'default'
            acceleration_controller_child.with_conf("default")
        elsif ::CONFIG_HACK == 'simulation'
            acceleration_controller_child.with_conf("default_simulation")
        elsif ::CONFIG_HACK == 'dagon'
            acceleration_controller_child.with_conf('default', 'all_thruster_huelle')
        end
        add AuvControl::AlignedToBody, :as => "aligned_to_body"
#        add Base::WorldXYZRollPitchYawControllerSrv, :as => "command"
#        command_child.prefer_deployed_tasks("constant_command")
        
        #conf 'simulation',
        #conf 'simulation', 'aligned_position_controller' => ['position_simulation_parallel'],
        #                   'aligned_velocity_controller' => ['default', 'velocity_simulation_parallel'],
        #                   'acceleration_controller' => ['default_simulation']
        #conf 'default',
        #conf 'default', 'aligned_position_controller' => ['default', 'position'],
        #                   'aligned_velocity_controller' => ['default', 'velocity'],
        #                   'acceleration_controller' => ['default', 'all_thruster_huelle']

#        command_child.connect_to world_to_aligned_child.cmd_in_port
        
        add ::Base::WorldXYZPositionControllerSrv, :as => 'controller'
        connect controller_child.world_command_port => world_to_aligned_child.cmd_in_port
        connect controller_child.aligned_position_command_port => aligned_position_controller_child.cmd_in_port

        pose_child.connect_to world_to_aligned_child
        pose_child.connect_to aligned_position_controller_child
        pose_child.connect_to aligned_velocity_controller_child
        pose_child.connect_to aligned_to_body_child
        pose_child.connect_to optimal_heading_controller_child
        world_to_aligned_child.cmd_out_port.connect_to optimal_heading_controller_child.cmd_cascade_port
        optimal_heading_controller_child.cmd_out_port.connect_to aligned_position_controller_child.cmd_cascade_port
        aligned_position_controller_child.cmd_out_port.connect_to aligned_velocity_controller_child.cmd_cascade_port
        aligned_velocity_controller_child.cmd_out_port.connect_to aligned_to_body_child.cmd_cascade_port
        aligned_to_body_child.cmd_out_port.connect_to acceleration_controller_child.cmd_cascade_port
        acceleration_controller_child.connect_to joint_child
        
        export world_to_aligned_child.cmd_in_port, :as => 'world_in'
        export aligned_velocity_controller_child.cmd_in_port, :as => 'velocity_in'
        export acceleration_controller_child.cmd_out_port
    #    provides ::Base::WorldZRollPitchYawControlledSystemSrv, :as => "world_in_s", "command_in" => "velocity_in"
    #    provides ::Base::XYVelocityControlledSystemSrv, :as => "velocity_in_s", "command_in" => "world_in"
        #provides ::WorldXYZRollPitchYawControlledSystemSrv, :as => 'controlled_system'
        provides ::Base::JointsCommandSrv, :as => "command_out"

        on :start do |event|
            controller_child.success_event.forward_to success_event
        end

    end

#    ::Base::ControlLoop.specialize ::Base::ControlLoop.controller_child => WorldPositionCmp
    #::Base::ControlLoop.specialize ::Base::ControlLoop.controller_child => WorldXYVelocityCmp
    #
    class WorldYPositionXVelocityCmp < Syskit::Composition

        add ::Base::JointsControlledSystemSrv, :as => "joint"
        add ::Base::PoseSrv, :as => "pose"
        add AuvCont::ConstantCommandGroundAvoidanceCmp, :as => 'avoid'
        add AuvControl::WorldToAligned.with_conf('default', 'no_xy'), :as => "world_to_aligned"
        add AuvControl::OptimalHeadingController.with_conf('default', 'no_xy'), :as => "optimal_heading_controller"
        #add AuvControl::PIDController.prefer_deployed_tasks("aligned_position_controller"), :as => "aligned_position_controller"
        #add AuvControl::PIDController.prefer_deployed_tasks("aligned_velocity_controller"), :as => "aligned_velocity_controller"
        add AuvControl::PIDController, :as => "aligned_position_controller"

        if ::CONFIG_HACK == 'default'
            aligned_position_controller_child.prefer_deployed_tasks("aligned_position_controller").with_conf("default", 'position_parallel', 'no_x')
        elsif ::CONFIG_HACK == 'simulation'
            aligned_position_controller_child.prefer_deployed_tasks("aligned_position_controller").with_conf("default", 'position_simulation_parallel', 'no_x')
        elsif ::CONFIG_HACK == 'dagon'
            aligned_position_controller_child.prefer_deployed_tasks("aligned_position_controller").with_conf('default_aligned_position', 'no_x')
        end

        add AuvControl::PIDController, :as => "aligned_velocity_controller"
        if  ::CONFIG_HACK == 'default'
            aligned_velocity_controller_child.prefer_deployed_tasks("aligned_velocity_controller").with_conf("dummy", 'velocity_parallel')
        elsif ::CONFIG_HACK == 'simulation'
            aligned_velocity_controller_child.prefer_deployed_tasks("aligned_velocity_controller").with_conf("dummy", 'velocity_simulation_parallel')
        elsif ::CONFIG_HACK == 'dagon'
            aligned_velocity_controller_child.prefer_deployed_tasks("aligned_velocity_controller").with_conf("default_aligned_velocity")
        end

        add AuvControl::AccelerationController, :as => "acceleration_controller"
        if  ::CONFIG_HACK == 'default'
            acceleration_controller_child.with_conf('default')
        elsif ::CONFIG_HACK == 'simulation'
            acceleration_controller_child.with_conf("default_simulation")
        elsif ::CONFIG_HACK == 'dagon'
            acceleration_controller_child.with_conf('default', 'all_thruster_huelle')
        end
        add AuvControl::AlignedToBody, :as => "aligned_to_body"
        add Base::WorldYPositionXVelocityControllerSrv, :as => "controller"
#        command_child.prefer_deployed_tasks("constant_command")
        
        #conf 'simulation',
        #conf 'simulation', 'aligned_position_controller' => ['position_simulation_parallel'],
        #                   'aligned_velocity_controller' => ['default', 'velocity_simulation_parallel'],
        #                   'acceleration_controller' => ['default_simulation']
        #conf 'default',
        #conf 'default', 'aligned_position_controller' => ['default', 'position'],
        #                   'aligned_velocity_controller' => ['default', 'velocity'],
        #                   'acceleration_controller' => ['default', 'all_thruster_huelle']

#        command_child.connect_to world_to_aligned_child.cmd_in_port

        #connect controller_child.world_command_port => world_to_aligned_child.cmd_in_port
        connect controller_child.world_command_port => avoid_child
        connect avoid_child => world_to_aligned_child.cmd_in_port
        connect controller_child.aligned_velocity_command_port => aligned_velocity_controller_child.cmd_in_port
        connect controller_child.aligned_position_command_port => aligned_position_controller_child.cmd_in_port

        connect pose_child => world_to_aligned_child
        connect pose_child => aligned_position_controller_child
        connect pose_child => aligned_velocity_controller_child
        connect pose_child => aligned_to_body_child
        connect pose_child => optimal_heading_controller_child
        connect world_to_aligned_child.cmd_out_port => optimal_heading_controller_child.cmd_cascade_port
        connect optimal_heading_controller_child.cmd_out_port => aligned_position_controller_child.cmd_cascade_port
        connect aligned_position_controller_child.cmd_out_port => aligned_velocity_controller_child.cmd_cascade_port
        connect aligned_velocity_controller_child.cmd_out_port => aligned_to_body_child.cmd_cascade_port
        connect aligned_to_body_child.cmd_out_port => acceleration_controller_child.cmd_cascade_port
        connect acceleration_controller_child => joint_child
        
        export world_to_aligned_child.cmd_in_port, :as => 'world_in'
        export aligned_velocity_controller_child.cmd_in_port, :as => 'velocity_in'
        export acceleration_controller_child.cmd_out_port
    #    provides ::Base::WorldZRollPitchYawControlledSystemSrv, :as => "world_in_s", "command_in" => "velocity_in"
    #    provides ::Base::XYVelocityControlledSystemSrv, :as => "velocity_in_s", "command_in" => "world_in"
        #provides ::WorldXYZRollPitchYawControlledSystemSrv, :as => 'controlled_system'
        provides ::Base::JointsCommandSrv, :as => "command_out"
    end
   
    class Trajectory < WorldPositionCmp 
        argument :reset, :default => false

        add_main  AvalonControl::TrajectoryFollower, :as => "main"
        overload 'controller', main_child

        connect pose_child => controller_child 
        event :reached_end
        event :align_at_end
        
    end

    class PositionMoveCmp < WorldPositionCmp
        add AuvControl::ConstantCommand.with_conf("default"), :as => 'command'
        command_child.prefer_deployed_tasks("constant_command")
        overload 'controller', command_child
        
        argument :heading, :default => 0
        argument :depth, :default => -4 
        argument :x, :default => 0
        argument :y, :default => 0
        argument :timeout, :default => nil
        argument :finish_when_reached, :default => nil #true when it should success, if nil then this composition never stops based on the position
        argument :event_on_timeout, :default => :success
        argument :delta_xy, :default => DELTA_XY
        argument :delta_z, :default => DELTA_Z
        argument :delta_yaw, :default => DELTA_YAW
        argument :delta_timeout, :default => DELTA_TIMEOUT
    
        attr_reader :start_time

        on :start do |ev|
                reader_port = nil
                if pose_child.has_port?('pose_samples')
                    reader_port = pose_child.pose_samples_port
                else
                    pose_child.each_child do |c| 
                        if c.has_port?('pose_samples')
                            reader_port = c.pose_samples_port
                            break
                        end
                    end
                end
                @reader = reader_port.reader 
                @start_time = Time.now
                Robot.info "Starting Position moving #{self}"
                command_child.update_config(:x => x, :heading => heading, :depth=> depth, :y => y, :pitch => 0, :roll => 0)
                @last_invalid_post = Time.new
        end
        
        poll do
            @last_invalid_pose = Time.new if @last_invalid_pose.nil?
            @start_time = Time.now if @start_time.nil?
            if @start_time.my_timeout?(timeout)
                Robot.info  "Finished Pos Mover because time is over! #{@start_time} #{@start_time + timeout}"
                emit event_on_timeout 
            end

            if finish_when_reached
                if @reader
                    if pos = @reader.read
                        if 
                            pos.position[0].x_in_range(x,delta_xy) and
                            pos.position[1].y_in_range(y,delta_xy) and
                            pos.position[2].depth_in_range(depth,delta_z) and
                            pos.orientation.yaw.angle_in_range(heading,delta_yaw)
                                @reached_position = true
                                if @last_invalid_pose.delta_timeout?(delta_timeout) 
                                    Robot.info "Hold Position, recalculating"
                                    emit :success
                                end
                        else
                            if @reached_position
                                Robot.info "################### Bad Pose! ################" 
                            end
                            @last_invalid_pose = Time.new
                            @reached_position = false
                        end
                    end
                end
            end
        end

    end

    class MoveCmp < WorldXYVelocityCmp
        add ConstantWorldXYVelocityCommand, :as => 'command'
#        command_child.prefer_deployed_tasks("constant_command")
        overload 'controller', command_child
        
        argument :heading, :default => 0
        argument :depth, :default => -4 
        argument :speed_x, :default => 0
        argument :speed_y, :default => 0
        argument :timeout, :default => nil
        argument :finish_when_reached, :default => nil #true when it should success, if nil then this composition never stops based on the position
        argument :event_on_timeout, :default => :success
        argument :delta_xy, :default => DELTA_XY
        argument :delta_z, :default => DELTA_Z
        argument :delta_yaw, :default => DELTA_YAW
        argument :delta_timeout, :default => DELTA_TIMEOUT
    
        attr_reader :start_time

        on :start do |ev|
                reader_port = nil
                if pose_child.has_port?('pose_samples')
                    reader_port = pose_child.pose_samples_port
                else
                    pose_child.each_child do |c| 
                        if c.has_port?('pose_samples')
                            reader_port = c.pose_samples_port
                            break
                        end
                    end
                end
                @reader = reader_port.reader 
                @start_time = Time.now
                Robot.info "Starting Position moving #{self}"
                command_child.update_config(:x => speed_x, :heading => heading, :depth=> depth, :y => speed_y)
                @last_invalid_post = Time.new
        end
        
        poll do
            @last_invalid_pose = Time.new if @last_invalid_pose.nil?
            @start_time = Time.now if @start_time.nil?
            if @start_time.my_timeout?(self.timeout)
                Robot.info  "Finished Simple Move because time is over! #{@start_time} #{@start_time + timeout}"
                emit event_on_timeout 
            end

        end


    end


    class StructureCmp < WorldXYVelocityCmp 
        event :aligned
        event :aligning
        event :servoing
        event :no_structure

        add_main Base::WorldXYVelocityControllerSrv, as: 'main'
        overload 'controller', main_child

#
#        on :aligned do |e|
#            emit :aligned
#            e
#        end
#
#        on :aligning do |e|
#            emit :aligning
#            e
#        end

        argument :timeout, :default => 60

        attr_reader :start_time

        on :start do |ev|
                @start_time = Time.now
                Robot.info "Starting structure moving #{self}"
                controller_child.servoing_event.forward_to servoing_event
                controller_child.no_structure_event.forward_to no_structure_event
        end
        
        poll do
            @start_time = Time.now if @start_time.nil?
            if @start_time.my_timeout?(self.timeout)
                Robot.info  "Finished Structure_inspection because time is over! #{@start_time} #{@start_time + timeout}"
                emit :success
            end

        end
        
    end

    class BuoyWallCmp < WorldXYZPositionCmp 
        event :aligned
        event :aligning

        add_main Base::WorldXYZPositionControllerSrv, as: 'main'
        overload 'controller', main_child


        on :aligned do |e|
            ::Robot.info "ALIGNED"
            emit aligned_event
            e
        end

        on :aligning do |e|
            ::Robot.info "ALIGNING"
            emit aligning_event
            e
        end


        
    end


end
    

