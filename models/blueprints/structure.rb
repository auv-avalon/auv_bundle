require 'models/blueprints/auv'
require 'models/blueprints/localization'

using_task_library 'structure_servoing'
using_task_library 'image_preprocessing'
using_task_library 'hsv_mosaicing'

module Structure 
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

        export detector_child.world_command_port, :as => "world_command"
        export detector_child.aligned_speed_command_port, :as => "speed_command"
        provides Base::WorldXYVelocityControllerSrv, :as => 'controller', "aligned_velocity_command" => "speed_command", "world_command" => "world_command" 

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
end


