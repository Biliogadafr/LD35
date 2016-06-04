extends Node

const MSG_NEW_CLIENT = 1
const MSG_CLIENT_ACCEPTED = 2
const MSG_RESOURCE_REGISTRY = 3
const MSG_SPAWN = 4
const MSG_STATE_SYNC = 5

var packet_peer = PacketPeerUDP.new()
var server_port = 31230
var connect_attempts = 20
var port = server_port
var ready = false
var host = false
var clients = []
var last_object_id = 0
var last_resource_id = 0

var network_objects = {} #network objects by id
var resource_registry = {}  #resource path from id
var resource_to_id = {}  #id from resource path

class NetworkObjectMeta:
	var service
	var id = -1
	var spawn_id = -1
	
func _ready():
	set_fixed_process(true)
	build_resource_list()
	init_tree_network_objects(get_tree().get_root())
	pass

func build_resource_list():
	search_for_resources_in_dir("res://")
	pass

#check what available scenes we have to be able to spawn objects from them.
func search_for_resources_in_dir(parent_path):
	var dir = Directory.new()
	if dir.open(parent_path) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while (file_name != ""):
			if(!file_name.begins_with(".")): # && file_name != ".." && file_name != "."):
				if dir.current_is_dir():
					search_for_resources_in_dir(str(parent_path, file_name, "/"))
				elif(file_name.extension().rfindn("scn") >= 0 || file_name.extension() == "xml"):
					var scene_path = parent_path+file_name
					print("Scene: ", scene_path)
					register_network_resource(scene_path)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to search for available resources")

#Attempt to collect all network objects that already spawned in scene at startup.
func init_tree_network_objects(parent_node):
	var children = parent_node.get_children()
	if children != null:
		for child in children:
			print(child.get_name())
			if(child.has_meta("network")):
				print("Registering network object in scene: ", child.get_name())
				register_network_node(child, null)
			init_tree_network_objects(child)

func _fixed_process(delta):
	var scene = get_tree().get_current_scene()
	if (ready):
		while (packet_peer.get_available_packet_count() > 0):
			var packet = packet_peer.get_var()
			if(packet == null):
				continue
			#print("packet", packet)
			var ip = packet_peer.get_packet_ip()
			var port = packet_peer.get_packet_port()
			
			if(host && packet[0] == MSG_NEW_CLIENT):
				if (!has_client(ip, port)):
					print("Client connected from ", ip, ":", port)
					var client_data = { ip = ip, port = port, seq = 0 }
					clients.append(client_data)
				
					packet_peer.set_send_address(ip, port)
					packet_peer.put_var([MSG_CLIENT_ACCEPTED])
					send_resource_registry(client_data)
				
					for net_object_id in network_objects:
						replicate_object(network_objects[net_object_id])
			
			if(host && packet[0] == MSG_SPAWN):
				var new_object = spawn(packet[2])
				replicate_object(new_object)
				#broadcast_to_clients(MSG_SPAWN, packet[2])
			
			if(!host && packet[0] == MSG_RESOURCE_REGISTRY && packet.size() == 2):
				receive_resource_registry(packet[1])
			
			if(!host && packet[0] == MSG_SPAWN):
				spawn(packet[2])
				
			if(!host && packet[0] == MSG_STATE_SYNC):
				receive_state(packet[2])
		
		#send state of objects
		if(host&&ready):
			send_state()
			
	
#If server - broadcast msg for all. If client - send to server
func send_msg(message_id, data):
	if(ready):
		if(host):
			broadcast_to_clients(message_id, data)
		else:
			send_to_server(message_id, data)

func send_to_server(message_id, data):
	packet_peer.put_var([message_id, 0, data])

func broadcast_to_clients(message_id, data):
	var packet = [message_id, 0, data]
	for client in clients:
		client.seq+=1
		packet[1] = client.seq
		packet_peer.set_send_address(client.ip, client.port)
		packet_peer.put_var(packet)

#send state of all registered objects to clients
func send_state():
	var state_list = [];
	for key in network_objects:
		var obj_state = network_objects[key].get_state()
		state_list.append({id = key, state = obj_state})
	broadcast_to_clients(MSG_STATE_SYNC, state_list)

#apply received state to all objects
func receive_state(state_list):
	for entry in state_list:
		if(network_objects.has(entry.id)):
			network_objects[entry.id].set_state(entry.state)

func start_server():
	port = server_port
	if (packet_peer.listen(port) != OK):
		print("Error listening on port ", port)
	else:
		print("Server started on port ", port)
		ready = true
		host = true
		
func connect_to_server(ip):
	while (packet_peer.listen(port) != OK):
		port += 1
	
	packet_peer.set_send_address(ip, server_port)
	
	var attempts = 0
	var connected = false
	
	while (!connected && attempts < connect_attempts):
		attempts += 1
		print("Connection attempt ", attempts)
		packet_peer.put_var([MSG_NEW_CLIENT])
		OS.delay_msec(50)
		
		while (packet_peer.get_available_packet_count() > 0):
			print("have some response from server...")
			var packet = packet_peer.get_var()
			if (packet != null and packet[0] == MSG_CLIENT_ACCEPTED):
				connected = true
				break
	
	if (!connected):
		print("Error connecting to ", ip, ":", server_port)
		return
	else:
		print("Connected to ", ip, ":", server_port)
		host = false
		ready = true
		delete_network_objects()
		
func delete_network_objects():
	for key in network_objects:
		network_objects[key].queue_free()
	network_objects.clear()

func stop_server():
	ready = false
	host = false
	packet_peer.close()
	print("Server stopped")
	
func has_client(ip, port):
	for client in clients:
		if (client.ip == ip && client.port == port):
			return true
	return false

func register_network_resource(network_resource):
	last_resource_id+=1
	resource_registry[last_resource_id] = load(network_resource)
	resource_to_id[network_resource] = last_resource_id

func register_network_node(network_node, external_id):
	var object_id
	#We could be forced to use external object ID if it was generated by server
	if(external_id != null):
		object_id = external_id
		if(external_id > last_object_id):
			last_object_id = external_id
		else:
			print("Looks like we already had object with that ID. Strange")
	else:
		last_object_id += 1
		object_id = last_object_id
	network_objects[object_id] = network_node
	var node_meta = NetworkObjectMeta.new()
	if(resource_to_id.has(network_node.get_filename())):
		node_meta.spawn_id = resource_to_id[network_node.get_filename()]
	else:
		print("No ", network_node.get_filename(), " in registry")
	node_meta.id = object_id
	node_meta.service = self
	network_node.set_meta("network", node_meta)
	return object_id
	
func send_resource_registry(client_data):
	packet_peer.set_send_address(client_data.ip, client_data.port)
	var simple_registry = {}
	for key in resource_registry:
		simple_registry[key] = resource_registry[key].get_path()
	packet_peer.put_var([MSG_RESOURCE_REGISTRY, simple_registry])
	
func receive_resource_registry(data):
	resource_registry.clear()
	resource_to_id.clear()
	for key in data:
		var resource_path = data[key]
		resource_registry[key] = load(resource_path)
		resource_to_id[resource_path] = key

func spawn_multiple(packet):
	for entry in packet:
		if(entry == MSG_SPAWN): continue #skip header
		spawn(entry)

#create new object from description
func spawn(entry):
	var spawned_object		
	if(host): #spawn new object on host
		spawned_object = resource_registry[entry.spawn_id].instance()
		get_tree().get_current_scene().add_child(spawned_object)
		register_network_node(spawned_object, null)
		spawned_object.set_meta("draft_id", entry.id)
	else:
		if(entry.has("draft_id") && network_objects.has(entry.draft_id)):
			#if this object was spawned inside this client we should receive correct ID from server
			var draft_id = entry.draft_id
			spawned_object = network_objects[draft_id]
			network_objects.erase(entry.draft_id)
			register_network_node(spawned_object, entry.id)
		else:
			#we just need to spawn new instance in client with server object id
			spawned_object = resource_registry[entry.spawn_id].instance()
			get_tree().get_current_scene().add_child(spawned_object)
			register_network_node(spawned_object, entry.id)
	spawned_object.set_state(entry.state)
	return spawned_object

#make this object appear on server or other clients
func replicate_object(object_to_replicate):
	if(typeof(object_to_replicate.get_meta("network")) != TYPE_OBJECT):
		register_network_node(object_to_replicate, null)
	var meta = object_to_replicate.get_meta("network")
	var object = {id = meta.id, spawn_id = meta.spawn_id, state = object_to_replicate.get_state()};
	if(object_to_replicate.has_meta("draft_id")):
		object.draft_id = object_to_replicate.get_meta("draft_id")
	send_msg(MSG_SPAWN, object)