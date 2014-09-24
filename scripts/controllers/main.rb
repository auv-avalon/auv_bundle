require 'highline'
require 'gdal-ruby/ogr'
CONSOLE = HighLine.new
def color(string, *args)
    CONSOLE.color(string, *args)
end

class TaskDummy
    def running?
        false
    end
end

# hafenbecken la spezia:
# 44.095741, 9.865195     östliche Ecke

def m2gps(x, y)
    from = Gdal::Osr::SpatialReference.new
    from.set_well_known_geog_cs('WGS84')
    to = Gdal::Osr::SpatialReference.new
    to.set_well_known_geog_cs('WGS84')
    to.set_utm(39, 1)
    
    origin_coord = 9.865012886520264,44.09616855137776,0
    q = Eigen::Quaternion.from_angle_axis( (230) / 180.0 * Math::PI, Eigen::Vector3.UnitZ )

    transform = Gdal::Osr::CoordinateTransformation.new(to, from)
    transform_inverse = Gdal::Osr::CoordinateTransformation.new(from, to)
    origin = transform_inverse.transform_point(origin_coord[1],origin_coord[0],0)

    v = Eigen::Vector3.new(x,y,0)
    v = q* v
    v = v + Eigen::Vector3.new(origin[0], origin[1],0)

    erg = transform.transform_point(v[0].to_f, v[1].to_f,0)


    return erg[0], erg[1]
end

def lat(x, y)
    m2gps(x,y)[0]
end

def lon(x, y)
    m2gps(x,y)[1]
end

def sauce_log
#    ::Robot.info State.time
#    ::Robot.info State.position
#    ::Robot.info State.current_state
    begin 
    "(#{State.time}, #{lat(State.position[:x], State.position[:y])}, #{lon(State.position[:x],State.position[:y])}, #{State.position[:z] * -1}, #{State.current_state[0]})\n"
    rescue Exception => e
        ::Robot.info "Got here #{e}"
        return e
    end
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

def process_child_tasks(task)
    task.coordination_objects.each do |m|
        if m.kind_of? Roby::Coordination::ActionStateMachine
            task.children.each do |child|
                process_child_tasks child
            end
            if m.root_task == task
                State.current_state_maschine << task.class.to_s.split('::')[1]
                State.current_state << "#{task.class.to_s.split('::')[1]} (#{m.current_task.name})"
            end
        end
    end
end


def tryGetTask(name)
    erg = TaskDummy.new
    begin
        erg = Orocos::TaskContext.get(name)
    rescue Exception => e
    end
    erg
end

State.current_sonar_conf = ['default']
Roby.every(1, :on_error => :disable) do
    wall = tryGetTask("wall_servoing") 
    localization = tryGetTask("uw_particle_localization")
    sonar = tryGetTask("sonar")
    
    if(wall.running?)
        sonar_conf = ['default','wall_right']
    else
        sonar_conf = ['default']
    end

    begin
        if(sonar.running?)
            if sonar_conf !=  State.current_sonar_conf
                ::Robot.info "Reconfiguring sonar to: #{sonar_conf}"
                sonar.apply_conf(sonar_conf,true)
                State.current_sonar_conf = sonar_conf
            end
        end
    rescue Exception => e
        ::Robot.warn "Somethig happening during application of our sonar hack"
        ::Robot.warn e 
    end
end
    
Roby.every(1, :on_error => :disable) do
    #STDOUT.puts "Searching for state_machines"
    State.current_state = []
    State.current_state_maschine = []
    Roby.plan.missions.to_a.each do |t|
        process_child_tasks(t)
    end
    State.current_state.reverse!
end

Roby.every(1, :on_error => :disable) do
    status = []

    Robot.warn "WATER INGRESS" if ::State.water_ingress == true
    Robot.warn "!!!!!!!   Logging disabled       !!!!" if LOG_DISABLED

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
        State.sv_task.create_output_port("current_state","/std/string")
        State.sv_task.create_output_port("current_state_maschine","/std/string")
        State.sv_task.create_output_port("current_mode","/std/string")
        State.sv_task.create_output_port("current_submode","/std/string")
        State.sv_task.configure
        State.sv_task.start
    end

    current_state = State.sv_task.port('current_state')
    current_state.write State.current_state.to_s
    current_state_maschine = State.sv_task.port('current_state_maschine')
    current_state_maschine.write State.current_state_maschine.to_s
    current_mode = State.sv_task.port('current_mode')
    current_mode.write State.current_mode.to_s
    current_submode = State.sv_task.port('current_submode')
    current_submode.write State.current_submode.to_s
end


State.time = 0
logfile = "sauce-log-#{Time.now}.log"
Roby.every(1, :on_error => :disable) do
    State.time = State.time + 1
    File.open(logfile, 'a+') do |file| 
        file.write(sauce_log) 
    end
end
