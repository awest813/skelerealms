class_name GOAPComponent
extends SKEntityComponent
## Planner for [GOAPAction]s that creates action sequences to complete a set of [Objective]s.


var agent_state:Dictionary = {}
var objectives:Array[Objective] = []
var action_queue:Array[GOAPAction] = []

var _current_action:GOAPAction
var _current_objective:Objective
var _agent:NavigationAgent3D
var _invoked:bool
var _timer:Timer
var _rebuild_plan:bool


func _init() -> void:
	name = "GOAPComponent"
	# add timer
	_timer = Timer.new()
	_timer.name = "Timer"
	_timer.one_shot = true
	add_child(_timer)


func _ready() -> void:
	for a:Node in get_children():
		if a is GOAPAction:
			a.entity = parent_entity
			a.parent_goap = self


func _process(delta:float) -> void:
	if GameInfo.is_loading:
		return
	# if we are set to rebuild our plan
	if _rebuild_plan:
		# Find the highest priority objective
		objectives.sort_custom(func(a:Objective, b:Objective): return a.priority > b.priority)
		for o in objectives:
			action_queue = _plan(get_children()\
				.filter(func(x): return x is GOAPAction)\
				.map(func(x): return x as GOAPAction), o.goals, {}\
			)
			# if we made a plan, stop sorting through objectives
			if not action_queue.is_empty():
				_pop_action()
				_current_objective = o # logically, this should be uncommented. But commenting it before made things work but now it's broken? what a load of crap
				_rebuild_plan = false
				break
	
	# if we are done with the plan
	if _current_objective and not _rebuild_plan and action_queue.is_empty() and not _current_action:
		# if we need to remove the objective, remove it
		if _current_objective.remove_after_satisfied:
			objectives.erase(_current_objective)
		# trigger plan rebuild next frame
		_rebuild_plan = true
	
	# if we are not done with the current action
	if not _current_action == null: 
		if _current_action.running:
			if _current_action.is_target_reached(_agent): # if agent navigation is finished
				if not _invoked: # if we aren't actively waiting for an action to be completed
					if _current_action.target_reached(): # call the target reached callback
						_invoke_in_time(_complete_current_action.bind(), _current_action.duration)
					else:
						_rebuild_plan = true
		else:
			if not action_queue.is_empty():
				_pop_action()
			else:
				_rebuild_plan = true


func _pop_action() -> void:
	_current_action = action_queue.pop_back()
	_current_action.running = true
	# if pre perform fails, rebuild plan
	if not _current_action.pre_perform():
		_rebuild_plan = true


## Creates a plan to satisfy a set of goals from all child [GOAPAction]s.
func _plan(actions:Array, goal:Dictionary, world_states:Dictionary) -> Array[GOAPAction]:
	var action_pool:Array = actions.filter(func(a:GOAPAction): return a.is_achievable()) # get all of the actions currently achievable.
	
	var leaves:Array[PlannerNode] = [] # create an array keeping track of all of the possible nodes that could make up our path.
	var start = PlannerNode.new(null, world_states, null, 0) # build the starting node.
	var success = _build_graph(start, leaves, goal, action_pool) # try to find a path.
	
	if not success: # if we have not found a path, we have failed.
		return []
		
	leaves.sort_custom(func(a:PlannerNode,b:PlannerNode): return a.cost < b.cost ) #Sort to find valid node with least cost.
	var cheapest:PlannerNode = leaves[0]
	
	var new_plan:Array[GOAPAction] = [] # create the plan for the AI to use. This will be treated like a queue.
	# walk back up the parent chain that the selected node has kept (sorta like a linked list) and build a queue from that.
	var n = cheapest 
	while not n.parent == null: # if it is null, we have reached the root node, since it will have no parents.
		new_plan.push_back(n.action)
		n = n.parent
	
	#new_plan.reverse()
	return new_plan


## BFS-based graph builder that finds all possible action chains satisfying the goal.
## Uses a queue instead of recursion so that the first complete plan found at
## each depth level is guaranteed to use the fewest actions. Combined with the
## cost sort on [code]leaves[/code] in [method _plan], this produces cost-optimal plans.
func _build_graph(start:PlannerNode, leaves:Array[PlannerNode], goal:Dictionary, action_pool:Array) -> bool:
	var found_path:bool = false
	# BFS queue: each entry is [PlannerNode, remaining_action_pool]
	var queue:Array = [[start, action_pool]]

	while queue.size() > 0:
		var entry:Array = queue.pop_front()
		var parent:PlannerNode = entry[0]
		var remaining_actions:Array = entry[1]

		# Get all actions that are:
		# 1) achievable
		# 2) achievable given current accumulated state
		# 3) would actually add new effects (not already satisfied)
		var achievable_actions = remaining_actions.filter(
			func(x:GOAPAction): return x.is_achievable() \
				and x.is_achievable_given(parent.states) \
				and not parent.states.has_all(x.get_effects().keys())
		)

		for action:GOAPAction in achievable_actions:
			# Duplicate the working state and apply this action's effects
			var current_state:Dictionary = parent.states.duplicate(true)
			current_state.merge(action.get_effects(), true)

			# Create a child node with accumulated cost
			var next_node:PlannerNode = PlannerNode.new(parent, current_state, action, parent.cost + action.cost)

			if _goal_achieved(goal, current_state):
				# Goal reached — record this leaf
				leaves.append(next_node)
				found_path = true
			else:
				# Remove the current action from the pool to prevent circular chains
				var subset:Array = remaining_actions.duplicate()
				subset.erase(action)
				# Enqueue for further expansion
				queue.append([next_node, subset])

	return found_path


## Determine whether we have satisfied all goals in our state.
func _goal_achieved(goal:Dictionary, current_state:Dictionary) -> bool:
	return current_state.has_all(goal.keys())


## Invoke a callable in a set amount of time.
func _invoke_in_time(f:Callable, time:float) -> void:
	# Invoke immediately if no duration
	if time == 0:
		f.call()
		return
	
	_invoked = true
	_timer.start(time)
	_timer.timeout.connect(func():
		# disconnect all events
		_clear_timer()
		# call function
		f.call()
	)


func _clear_timer() -> void:
	for c in _timer.timeout.get_connections():
		_timer.timeout.disconnect(c.callable)


## Wrap up the running action.
func _complete_current_action() -> void:
	_current_action.running = false
	# if post perform fails, rebuild plan
	if not _current_action.post_perform():
		_rebuild_plan = true
	_invoked = false


## Add an objective for this asgent to attempt to satisfy.
func add_objective(goals:Dictionary, remove_after_satisfied:bool, priority:float) -> Objective:
	var o = Objective.new(goals, remove_after_satisfied, priority)
	objectives.append(o)
	_rebuild_plan = true
	return o


func remove_objective_by_goals(goals:Dictionary) -> void:
	var to_remove = objectives.filter(func(x:Objective): return x.goals == goals)
	for o in to_remove:
		objectives.erase(o)


func regenerate_plan() -> void:
	_rebuild_plan = true


func interrupt() -> void:
	if _current_action:
		_current_action.interrupt()
		_timer.stop() # cancel callback
	regenerate_plan()


func gather_debug_info() -> String:
	return """
[b]GOAPComponent[/b]
	Objectives: %s
	Current objective: %s
	Current action: %s (Running: %s)
	Action queue: %s
	Current action duration: %s
	Remaining action time: %s / %s (Timer running: %s)
	Target reached: %s (Final point: %s, Target Distance: %s)
""" % [
	objectives\
		.map(func(o:Objective): return o.serialize())\
		.reduce(func(sum, next): return sum + next, ""),
	_current_objective.serialize() if _current_objective else "None",
	_current_action.name if _current_action else "None",
	_current_action.running if _current_action else "false",
	" -> ".join(
		(
			func():
				var x = action_queue.map(func(action:GOAPAction): return action.name)
				x.reverse()
				return x
				).call()
		),
	-1 if _current_action == null else _current_action.duration,
	_timer.time_left,
	_timer.wait_time,
	not _timer.is_stopped(),
	"No agent" if _agent == null else _agent.is_target_reached(),
	"No agent" if _agent == null else _agent.get_final_position(),
	"No agent" if _agent == null else _agent.target_desired_distance
]


## An objective for the AI to try to solve for.
class Objective:
	## Goals to satisfy this objective.
	var goals:Dictionary
	## Whether to remove this goal after it is satisfied.
	var remove_after_satisfied:bool
	## Priority
	var priority:float
	
	func _init(g:Dictionary, rem:bool, p:float) -> void:
		goals = g
		remove_after_satisfied = rem
		priority = p
	
	func serialize() -> String:
		return """
		Remove after satisfied: %s
		Priority: %s
		Goals: %s
		""" % [
			remove_after_satisfied,
			priority,
			JSON.stringify(goals, '\t')
		]


## Internal node for planning a GOAP chain.
class PlannerNode:
	var parent:PlannerNode
	var action:GOAPAction
	var cost:float
	var states:Dictionary
	
	
	func _init(p:PlannerNode, s:Dictionary, a:GOAPAction, c:float) -> void:
		parent = p
		action = a
		cost = c
		states = s
