using_task_library 'sonar_feature_detector'
class SonarFeatureDetector::Task
    def fix
        orocos_task.fix_map
    end
end
