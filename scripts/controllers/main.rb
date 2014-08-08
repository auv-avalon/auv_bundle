require 'highline'
CONSOLE = HighLine.new
def color(string, *args)
    CONSOLE.color(string, *args)
end

def add_status(status, name, format, obj, field, *colors)
    if !field.respond_to?(:to_ary)
        field = [field]
    end

    value = field.inject(obj) do |value, field_name|
        if value.respond_to?(field_name)
            value.send(field_name)
        else break
        end
    end

    if value
        if block_given?
            value = yield(value)
        end

        if value
            if format
                if !value.respond_to?(:to_ary)
                    value = [value]
                end

                status << color("#{name}=#{format}" % value, *colors)
            else
                status << color(name, *colors)
            end
        end
    else
        status << "#{name}=-"
    end
end

@i = 0


def find_parent_task_for_task(current_task,task)
#    STDOUT.puts "Called with #{task}"
    current_task.children.to_a.each do |child|
        if child == task
            return current_task
        else
            return find_parent_task_for_task(child,task)
        end
    end
    return nil
end

@mission_cache = []

#def create_modified_missions(missions,new_state,machine)
#
#    missions.each do |m|
##        STDOUT.puts "Current: #{machine.current_task}, child: #{m.children.to_a[0]}"
##        binding.pry
#        #if machine.current_task == m.children.to_a[0]
#        parent = find_parent_task_for_task(m,machine.current_task.task) 
#        if parent
##            parent.remove_dependency(machine.current_task.task)
##            binding.pry
##            machine.update_root_task parent
##            machine.instanciate_state(new_state)
##            STDOUT.puts "---------------------- new missions\n#{missions.size}\n-----------------"
#            Roby.plan.prepare_switch(missions,[])
##            binding.pry
#            #STDOUT.puts "######################################### JEEEEEEEEEHAAAAAAAAAAAAAAAAAAAAAAAAAA #################################################### \n#{parent}"
#        end
#    end
#end
    

def process_child_tasks(task)
    task.children.each do |child|
        process_child_tasks child
    end
    state_machines = Roby::Coordination.instances.select{|t| t.kind_of?(Roby::Coordination::ActionStateMachine)}
    state_machines.each do |m|
        if m.root_task == task
            STDOUT.puts "Found state-machine #{m} in state #{m.current_task}"
            STDOUT.puts "Possible followers: #{m.possible_following_states}"
            m.possible_following_states.each do |s|

                req_tasks_org = Roby.plan.find_local_tasks(Syskit::InstanceRequirementsTask).
                    find_all do |req_task|
                        !req_task.failed? && !req_task.pending? &&
                            req_task.planned_task && !req_task.planned_task.finished?
                    end
                not_needed = Roby.plan.unneeded_tasks
                req_tasks = req_tasks_org.dup
                removed = "Removed\n "
                req_tasks.delete_if do |t|
                    #Removing the current object if t is the parent of the running task
                    removed <<  "#{t}\n" if not_needed.include?(t) or t.parent_object?(m.current_task.task)
                    not_needed.include?(t) or t.parent_object?(m.current_task.task) 
                end

                #Caching the FROM-> to transition for this state
                next if @mission_cache.include?([req_tasks_org,s])
                @mission_cache << [req_tasks_org,s]
                
                #@Sylvain is here anything else needed?
                #I have a problem here, if i do the following line, the state is imidiatly executed.
                #Avalon should pass the pipeline once and then turn to the other direction
                #i i have the following line, then avalon directly follows the pipeline to the 
                #second's state-direction
                new = s.action.to_instance_requirements
                STDOUT.puts "#{removed} Added: \n#{new}"
                req_tasks << new
                Roby.plan.prepare_switch(req_tasks)
            end
        end
    end
end

@first=false
=begin
Roby.every(1, :on_error => :disable) do
    #return
    #Waiting until we start our search algorithm
    #This is the 'core' basis of the realtime-adaptation
    #this and the following functions are triing to calculate all 
    #following states, and the needed transactions to transistion to them.
    @i = @i+1
    if @i > 20
        if @first
            STDOUT.puts "*******************************************************************************************"
            STDOUT.puts "*********************************Starging precalculaion************************************"
            STDOUT.puts "*******************************************************************************************"
        end
        STDOUT.puts "Searching for state_machines"
        Roby.plan.missions.to_a.each do |t|
            process_child_tasks(t)
        end
        if @first
            STDOUT.puts "*******************************************************************************************"
            STDOUT.puts "*********************************Finished precalculaion************************************"
            STDOUT.puts "*******************************************************************************************"
            @first = false
        end
    end
end
=end
Roby.every(1, :on_error => :disable) do
    status = []

    Robot.warn "WATER INGRESS" if ::State.water_ingress == true

    add_status(status, "state", "%i", State, :lowlevel_state)
    add_status(status, "sub-state", "%i", State, :lowlevel_substate)
    add_status(status, "pos", "(x=%.2f y=%.2f z=%.2f)", State, [:pose, :position]) do |p|
        p.to_a
    end
    add_status(status, "heading", "(%.2f deg, %.2f rad)", State, [:pose, :orientation]) do |q|
        [q.yaw * 180.0 / Math::PI, q.yaw]
    end
    add_status(status, "target z", "(%.2f m)", State, :target_depth) 
    add_status(status, "Min-Cell", "(%.2fV)", State, :lowest_cell) 
    Robot.info status.join(' ') if !status.empty?
end

State.sv_task = nil

Roby.every(1, :on_error => :disable) do
    if State.sv_task.nil?
        State.sv_task = Orocos::RubyTaskContext.new("supervision") 
        State.sv_task.create_output_port("actual_state","/std/string")
        State.sv_task.create_output_port("delta_depth","double")
        State.sv_task.create_output_port("delta_heading","double")
        State.sv_task.create_output_port("delta_x","double")
        State.sv_task.create_output_port("delta_y","double")
        State.sv_task.create_output_port("delta_timeout","double")
        State.sv_task.create_output_port("timeout","double")
        State.sv_task.configure
        State.sv_task.start
    end
end
