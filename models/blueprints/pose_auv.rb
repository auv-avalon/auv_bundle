using_task_library "xsens_imu"
using_task_library "fog_kvh"
using_task_library "orientation_estimator"
using_task_library "depth_reader"
using_task_library "uw_particle_localization"


require "rock/models/blueprints/pose"
require "models/blueprints/auv.rb"

module PoseAuv
    class DagonOrientationEstimator < Syskit::Composition
        add OrientationEstimator::BaseEstimator, :as => 'estimator'
        add UwParticleLocalization::OrientationCorrection, :as => 'correction'

        add Base::OrientationSrv, :as => 'imu'
        add FogKvh::Dsp3000Task, :as => 'fog'

        #imu_child.connect_to correction_child.absolute_orientation_port
        estimator_child.connect_to correction_child.orientation_input_port

        imu_child.connect_to  estimator_child.imu_orientation_port
        fog_child.connect_to  estimator_child.fog_samples_port

        #export estimator_child.attitude_b_g_port, :as => 'orientation_samples'
        export correction_child.orientation_output_port, :as => 'orientation_samples'
        #export correction_child.orientation_offset_corrected_port, :as => 'orientation_samples'
        provides Base::OrientationSrv, :as => "orientation"
    end

#    class OrientationWithZ < Syskit::Composition 
#        add DepthReader::DepthAndOrientationFusion, :as => 'fusion'
#        
#        #add Srv::Orientation
#        add DagonOrientationEstimator, :as => 'orientation'
#        add Base::ZProviderSrv, :as => 'z_provider'
#
#        orientation_child.connect_to fusion_child.orientation_samples_port
#        z_provider_child.connect_to  fusion_child.depth_samples_port
#
#        export fusion_child.pose_samples_port
#        provides Base::OrientationWithZSrv, :as => "orientation_with_z"
#        provides Base::VelocitySrv, :as => "speed"
#    end
end
