require 'models/blueprints/auv'
require 'models/blueprints/localization'

using_task_library 'structure_servoing'
using_task_library 'image_preprocessing'
using_task_library 'hsv_mosaicing'
using_task_library 'sonar_structure_servoing'
using_task_library 'structure_reconstruction'

module Structure 
    class Alignment < Syskit::Composition
        event :aligning
        event :aligned
        event :no_structure

        add_main StructureServoing::Alignment , :as => 'detector'
        add HsvMosaicing::Task, :as => "mosaic" 
        add ImagePreprocessing::HSVSegmentationAndBlur, :as => "seg" 
        if  ::CONFIG_HACK == 'default'
            seg_child.with_conf("structure")
        elsif ::CONFIG_HACK == 'simulation'
            seg_child.with_conf("structure_simulation")
        elsif ::CONFIG_HACK == 'dagon'
            seg_child.with_conf('structure')
        end
        add Base::ImageProviderSrv, :as => 'camera'

        connect camera_child => seg_child
        connect seg_child.binary_result_port => mosaic_child
        connect mosaic_child => detector_child
    
        #export detector_child.size_port, :as => "size"
        export detector_child.world_command_port, :as => "world_command"
        export detector_child.aligned_speed_command_port, :as => "speed_command"
        provides Base::WorldXYVelocityControllerSrv, :as => 'controller', "aligned_velocity_command" => "speed_command", "world_command" => "world_command" 
    end


    class Detector < Syskit::Composition
        add_main StructureServoing::Task, :as => 'detector'
        add HsvMosaicing::Task, :as => "mosaic" 
        add ImagePreprocessing::HSVSegmentationAndBlur.with_conf('structure'), :as => "seg" 
        add Base::ImageProviderSrv, :as => 'camera'
        add Base::OrientationWithZSrv, :as => "ori"


        connect ori_child => detector_child 
        connect camera_child => seg_child
        connect seg_child.binary_result_port => mosaic_child
        connect mosaic_child => detector_child
    
        #export detector_child.size_port, :as => "size"
        export detector_child.world_command_port, :as => "world_command"
        export detector_child.aligned_speed_command_port, :as => "speed_command"
        provides Base::WorldXYVelocityControllerSrv, :as => 'controller', "aligned_velocity_command" => "speed_command", "world_command" => "world_command" 

        event :servoing
        event :no_structure

#
#        event :wall_servoing
#        event :searching_wall
#        event :checking_wall
#        event :detected_corner
#        event :lost_all
#        event :origin_alignment
#        event :alignment_complete
#        argument :timeout, :default => nil
#        argument :max_corners, :default => nil
#
#        attr_accessor :num_corners
#
#        on :start do |event|
#            Robot.info "Starting Wall Servoing"
#            self.num_corners = 0
#            @start_time = Time.now
#            
#            
#            Robot.info "Starting wall detector reconfiguring sonar to wall_right"
#            @sonar_workaround = true 
#            if sonar_child.respond_to?(:orocos_task)
#                @old_sonar_conf = sonar_child.conf
#            else
#                #Simulation special case
#                @old_sonar_conf = sonar_child.children.to_a[1].conf
#            end
#        end
#
#        def corner_passed!
#            @num_corners = @num_corners + 1 
#        end
#
#        on :detected_corner do |e|
#            self.corner_passed!
#            Robot.info "Passed a corner, have passed #{self.num_corners}"
#        end
#
#        poll do
#            if(self.timeout)
#                if(@start_time + self.timeout < Time.now)
#                    STDOUT.puts "Finished #{self} becaue time is over! #{@start_time} #{@start_time + self.timeout}"
#                    emit :success
#                end
#            end
#            if(self.max_corners)
#                if(num_corners == self.max_corners)
#                    Robot.info "Wall servoing succssfull get all corners"
#                    emit :success
#                end
#            end
#
#            #Workaround sonar configs
#            orocos_t = nil
#            if sonar_child.respond_to?(:orocos_task)
#                orocos_t = sonar_child.orocos_task
#            else
#                #Simulation special case
#                orocos_t = sonar_child.find_child {|c| c.class == Simulation::Sonar }.orocos_task
#            end
#
#            if orocos_t.state == :RUNNING and @sonar_workaround
#                condition = true
#                if sonar_child.respond_to?(:orocos_task)
#                    condition = orocos_t.config.continous == 1
#                else
#                    condition = orocos_t.ping_pong_mode == false
#                    #Nothing for sim, workarounding always
#                end
#
#                if condition 
#                    STDOUT.puts "Overriding sonar config to wall right"
#                    orocos_t.apply_conf(['default','wall_servoing_right'],true)
#                    @sonar_workaround = false
#                else
#                    @sonar_workaround = false
#                    STDOUT.puts "Sonar config is fine did you solved the config issues? #{orocos_t.config.continous}"
#                end
#            end
#        end
    end


    class SonarStructureServoingComp < Syskit::Composition
        add_main SonarStructureServoing::Task, :as => 'detector'
        add Base::SonarScanProviderSrv, :as => 'sonar'
        add SonarFeatureEstimator::Task, :as => 'sonar_estimator'
        add Base::PoseSrv, :as => 'pose_blind'

        if ::CONFIG_HACK == 'default'
            detector_child.with_conf("default", 'move_left')
        elsif ::CONFIG_HACK == 'simulation'
            detector_child.with_conf("default", 'simulation', 'move_left')
        elsif ::CONFIG_HACK == 'dagon'
            detector_child.with_conf("default", 'move_left')
        end
        sonar_child.with_conf("default", 'structure_servoing_front')

        connect sonar_child => sonar_estimator_child
        connect sonar_estimator_child => detector_child
	    connect pose_blind_child => detector_child.odometry_samples_port

        export detector_child.world_command_port
        export detector_child.aligned_position_command_port
        provides Base::WorldXYPositionControllerSrv, :as => 'controller'

        export detector_child.position_command_port
        provides Base::AUVRelativeMotionControllerSrv, :as => 'old_controller'

        event :MISSING_TRANSFORMATION
        event :SEARCHING_STRUCTURE
        event :VALIDATING_STRUCTURE
        event :INSPECTING_STRUCTURE

    end

    class StructureReconstructionComp < Syskit::Composition
        add_main StructureReconstruction::Task, :as => 'image_saver'
        add Base::ImageProviderSrv, :as => 'front_camera'
        add Base::ImageProviderSrv, :as => 'bottom_camera'

        connect front_camera_child => image_saver_child.front_camera_port
        connect bottom_camera_child => image_saver_child.bottom_camera_port
        
        event :MISSING_TRANSFORMATION
    end

end


