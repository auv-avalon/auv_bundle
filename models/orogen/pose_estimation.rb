class PoseEstimation::UWPoseEstimator
    worstcase_processing_time 1.0
    def reset_heading(angle_in_rad)
         orocos_task.reset_heading(angle_in_rad)
    end
end
