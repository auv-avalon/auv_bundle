require "rock/models/blueprints/control"


class OffshorePipelineDetector::Task
    attr_reader :options

    def configure
        super
        return if(!@options)
        orocos_task.depth = @options[:depth] if @options[:depth]
        orocos_task.prefered_heading = @options[:heading] if @options[:heading]
        orocos_task.default_x = @options[:speed_x] if @options[:speed_x]
        orocos_task.preffered_turn_direction = @options[:turn_dir] if @options[:turn_dir]
    end

    def update_config(options)
        @options = options
        orocos_task.depth = options[:depth] if options[:depth]
        orocos_task.prefered_heading = options[:heading] if options[:heading]
        orocos_task.default_x = options[:speed_x] if options[:speed_x]
        orocos_task.preffered_turn_direction = @options[:turn_dir] if @options[:turn_dir]
    end
end


