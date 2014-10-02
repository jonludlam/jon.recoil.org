We had an issue reported by XenRT that xapi was failing during a
stress test while halting a VM, reporting an internal error from
xenopsd: "Object does not exist in xenopsd".

Looking through /var/log/xensource.log, the API call comes in
for processing at 19:31:44:

```
May  2 19:31:44 localhost xapi: [ info|cl11-08|46298 INET 0.0.0.0:80|dispatch:VM.clean_shutdown D:fa4c1c72df7e|taskhelper] task Async.VM.clean_shutdown R:82f033257476 forwarded (trackid=8354dc542edb45d9d747e9c1d992c886)
```

Xapi log lines are very long and contain quite a lot of
info. Decomposing it a bit, this particular line is an info message on
host cl11-08, thread id 46298 from the TCP port listening to
0.0.0.0:80. It's a task called `dispatch:VM.clean_shutdown`, which has
task id `D:fa4c1c72df7e`, and comes from a logger named `taskhelper`,
which is defined
[here](https://github.com/xapi-project/xen-api/blob/9abf1c73923598b3598e41e539ec49d60c51c588/ocaml/idl/ocaml_backend/taskHelper.ml#L14)
The log message says that there's a new task 'Async.VM.clean_shutdown'
with task id R:82f033257476, which has been forwarded from the pool
master.

The bit we're interested in here is that the new task id is
`R:82f033257476`, and we can grep for this in the logs to see only the
messages associated with this API call. Doing that and skipping a few
uninteresting lines, we see that xapi decides this is an OK thing to
process, and in turn tells xenopsd to halt the VM:

```
May  2 19:31:44 localhost xapi: [debug|cl11-08|46298 INET 0.0.0.0:80|Async.VM.clean_shutdown R:82f033257476|mscgen] xapi=>xenops [label="VM.shutdown"];
May  2 19:31:44 localhost xenopsd: [debug|cl11-08|7|Async.VM.clean_shutdown R:82f033257476|xenops] Task 7729 reference Async.VM.clean_shutdown R:82f033257476: ["VM_poweroff", ["4ab3dfd9-f571-8900-a35a-6cced68267e3", [1200.000000]]]
```

The `mscgen` line shows an internal `VM.shutdown` call from xapi to
xenopsd.  The entry points for all of the xenopsd API calls are in the
file xenopsd.git/lib/xenops_server.ml, and this particular call is
handled
[here](https://github.com/xapi-project/xenopsd/blob/25fc99435dbe5093b10f8727198a94097ba22031/lib/xenops_server.ml#L1727)
which shows why xenopsd logs it as VM_poweroff.

Xenopsd turns this API call into
[several smaller items](https://github.com/xapi-project/xenopsd/blob/25fc99435dbe5093b10f8727198a94097ba22031/lib/xenops_server.ml#L809)
and starts processing them, logging when it starts each one:

```
May  2 19:31:44 localhost xenopsd: [debug|cl11-08|7|Async.VM.clean_shutdown R:82f033257476|xenops] Performing: ["VM_hook_script", ["4ab3dfd9-f571-8900-a35a-6cced68267e3", "VM_pre_destroy", "clean-shutdown"]]
...
May  2 19:31:44 localhost xenopsd: [debug|cl11-08|7|Async.VM.clean_shutdown R:82f033257476|xenops] Performing: ["VM_shutdown_domain", ["4ab3dfd9-f571-8900-a35a-6cced68267e3", "Halt", 1200.000000]]
...
May  2 19:32:09 localhost xenopsd: [debug|cl11-08|7|Async.VM.clean_shutdown R:82f033257476|xenops] Performing: ["VM_destroy_device_model", "4ab3dfd9-f571-8900-a35a-6cced68267e3"]
...
May  2 19:32:09 localhost xenopsd: [debug|cl11-08|7|Async.VM.clean_shutdown R:82f033257476|xenops] Performing: ["VBD_unplug", ["4ab3dfd9-f571-8900-a35a-6cced68267e3", "xvda"], true]
...
May  2 19:32:25 localhost xenopsd: [debug|cl11-08|7|Async.VM.clean_shutdown R:82f033257476|xenops] Performing: ["VIF_unplug", ["4ab3dfd9-f571-8900-a35a-6cced68267e3", "0"], true]
...
May  2 19:32:26 localhost xenopsd: [debug|cl11-08|7|Async.VM.clean_shutdown R:82f033257476|xenops] Performing: ["VM_destroy", "4ab3dfd9-f571-8900-a35a-6cced68267e3"]
...
May  2 19:32:26 localhost xenopsd: [debug|cl11-08|7|Async.VM.clean_shutdown R:82f033257476|xenops] Performing: ["VBD_epoch_end", [["4ab3dfd9-f571-8900-a35a-6cced68267e3", "xvda"], ["VDI", "0da34c7b-b27b-20c3-7e29-50659204a52e\/9f380254-3a77-452a-aea3-8031226c6cc7"]]]
...
May  2 19:32:45 localhost xenopsd: [debug|cl11-08|7|Async.VM.clean_shutdown R:82f033257476|xenops] Performing: ["VBD_set_active", ["4ab3dfd9-f571-8900-a35a-6cced68267e3", "xvda"], false]
May  2 19:32:45 localhost xenopsd: [debug|cl11-08|7|Async.VM.clean_shutdown R:82f033257476|xenops] VBD.set_active 4ab3dfd9-f571-8900-a35a-6cced68267e3.xvda false
May  2 19:32:45 localhost xenopsd: [ info|cl11-08|7|Async.VM.clean_shutdown R:82f033257476|xenops] Caught Xenops_interface.Does_not_exist(_) executing ["VM_poweroff", ["4ab3dfd9-f571-8900-a35a-6cced68267e3", [1200.000000]]]: triggering cleanup actions
```

The first thing to notice is that the system must be really busy, as
it takes over a minute to fail to poweroff the VM. We can also clearly
see that it's in processing the `VBD.set_active` task that the failure
occurs. Unhelpfully, the body of the exception `Does_not_exist` has
been hidden, but fortunately xenopsd logs the full details a few lines
later:

```
May  2 19:32:45 localhost xenopsd: [debug|cl11-08|7|Async.VM.clean_shutdown R:82f033257476|xenops] Task 7729 failed; exception = ["Does_not_exist", ["VM", "4ab3dfd9-f571-8900-a35a-6cced68267e3\/vbd.xvda"]]
```

and so it's complaining that the _VM_ does not exist. This can only
have happened by a VM.remove call being processed by xenopsd. Grepping
for this:

```
May  2 19:32:31 localhost xapi: [debug|cl11-08|74|xenops events D:337bbe7c241d|xenops] Processing event: ["Vm", "4ab3dfd9-f571-8900-a35a-6cced68267e3"]
May  2 19:32:31 localhost xapi: [debug|cl11-08|74|xenops events D:337bbe7c241d|xenops] xenops event on VM 4ab3dfd9-f571-8900-a35a-6cced68267e3
May  2 19:32:31 localhost xapi: [debug|cl11-08|74|xenops events D:337bbe7c241d|mscgen] xapi=>xenops [label="VM.stat"];
May  2 19:32:31 localhost xenopsd: [debug|cl11-08|13680588|xenops events D:337bbe7c241d|xenops] VM.stat 4ab3dfd9-f571-8900-a35a-6cced68267e3
May  2 19:32:31 localhost xapi: [debug|cl11-08|74|xenops events D:337bbe7c241d|xenops] xenopsd event: processing event for VM 4ab3dfd9-f571-8900-a35a-6cced68267e3
May  2 19:32:31 localhost xapi: [debug|cl11-08|74|xenops events D:337bbe7c241d|xenops] Will update VM.allowed_operations because power_state has changed.
May  2 19:32:31 localhost xapi: [debug|cl11-08|74|xenops events D:337bbe7c241d|xenops] xenopsd event: Updating VM 4ab3dfd9-f571-8900-a35a-6cced68267e3 power_state <- Halted
May  2 19:32:33 localhost xapi: [debug|cl11-08|74|xenops events D:337bbe7c241d|xenops] xenops_cache: deleting cache for 4ab3dfd9-f571-8900-a35a-6cced68267e3
May  2 19:32:33 localhost xapi: [debug|cl11-08|74|xenops events D:337bbe7c241d|xenops] xapi_cache: deleting cache for 4ab3dfd9-f571-8900-a35a-6cced68267e3
May  2 19:32:33 localhost xapi: [ info|cl11-08|74|xenops events D:337bbe7c241d|xenops] xenops: VM.remove 4ab3dfd9-f571-8900-a35a-6cced68267e3
May  2 19:32:33 localhost xapi: [debug|cl11-08|74|xenops events D:337bbe7c241d|mscgen] xapi=>xenops [label="VM.remove"];
```

So xapi told xenopsd to remove the VM! The clue here is in the name of
the thread: `xenops events`.  Xapi has to be able to respond to events
initiated by the VM, for example, the VM may shut down at any time and
xapi needs to reflect this in its database. Therefore a thread exists
in xapi that monitors xenopsd for events. This thread has noticed that
the VM has shut down and attempts to clean things up. Normally this
isn't a problem as xenopsd only marks the VM as shut down when it
performs the `VM_destroy` towards the end of its shutdown actions, and
in any case it wouldn't usually signal an event on the VM until
completely finishing the sequence.

In this case, probably because the whole system was very busy, the
event thread presumably had a long queue of events to process,
including one that came from this VM from before the shutdown was
initiated. This was then processed at an unfortunate time, leading to
the problem. To confirm, we can inject this sort of failure by
modifying the sequence of events that happens during a shutdown:

From this:

```ocaml
| VM_poweroff (id, timeout) ->
    let reason =
        if timeout = None
        then Xenops_hooks.reason__hard_shutdown
        else Xenops_hooks.reason__clean_shutdown in
    [
        VM_hook_script(id, Xenops_hooks.VM_pre_destroy, reason);
    ] @ (atomics_of_operation (VM_shutdown (id, timeout))
    ) @ (List.concat (List.map (fun vbd -> Opt.default [] (Opt.map (fun x -> [ VBD_epoch_end (vbd.Vbd.id, x)] ) vbd.Vbd.backend))
        (VBD_DB.vbds id)
    )) @ (List.map (fun vbd -> VBD_set_active (vbd.Vbd.id, false))
        (VBD_DB.vbds id)
    ) @ (List.map (fun vif -> VIF_set_active (vif.Vif.id, false))
        (VIF_DB.vifs id)
    ) @ [
        VM_hook_script(id, Xenops_hooks.VM_post_destroy, reason)
    ]
```

we'll stick in a delay:


```ocaml
| VM_poweroff (id, timeout) ->
    let reason =
	    if timeout = None
	    then Xenops_hooks.reason__hard_shutdown
	    else Xenops_hooks.reason__clean_shutdown in
	[
	    VM_hook_script(id, Xenops_hooks.VM_pre_destroy, reason);
	] @ (atomics_of_operation (VM_shutdown (id, timeout))
	) @ [ VM_delay (id, 10.0);
	] @ (List.concat (List.map (fun vbd -> Opt.default [] (Opt.map (fun x -> [ VBD_epoch_end (vbd.Vbd.id, x)] ) vbd.Vbd.backend))
	    (VBD_DB.vbds id)
	)) @ (List.map (fun vbd -> VBD_set_active (vbd.Vbd.id, false))
	    (VBD_DB.vbds id)
	) @ (List.map (fun vif -> VIF_set_active (vif.Vif.id, false))
	    (VIF_DB.vifs id)
	) @ [
	    VM_hook_script(id, Xenops_hooks.VM_post_destroy, reason)
	]

```

and separately cause the `VM_delay` atomic operation to inject an event that xapi
will pick up:

```ocaml
| VM_delay (id, t) ->
    Updates.add (Dynamic.Vm id) updates;
	debug "VM %s: waiting for %.2f before next VM action" id t;
	Thread.delay t
```

where that 'Updates.add' is what will wake xapi.
Compiling this up and uploading it to our server, the problem is easily reproduced:

```bash
[root@st28 ~]# xe vm-shutdown vm=centos
The server failed to handle your request, due to an internal error.  The given message may give details useful for debugging the problem.
message: Object with type VM and id 41bcbb30-31b6-5d97-37ad-c8b1f985c064/vbd.xvdd does not exist in xenopsd
```

Now we just need to decide how to fix this. It seems bad that invoking
this API call to xenopsd can cause it an internal error, so the
problem should clearly be fixed in xenopsd as opposed to within xapi.
Fortunately xenopsd already has logic for this sort of thing: It has
system of worker threads that perform the larger operations and a way
of queuing operations to be processed. This allows xenopsd to process
several operations at the same time.

When a new VM-specific operation is queued, xenopsd looks to see if a
worker thread is already processing operations on that particular
VM. If so, the operation is given to that worker's personal queue, and
if not, the operation is put onto the default queue. When a worker is
looking for a job to do, it pops the next operation off the default
queue, and also allocates all other operations on the same VM to
itself.  In this way we never have two workers trying to operate on
the same VM.

The solution is therefore to use this mechanism to queue up the VM.remove
behind the VM.shutdown. Unfortunately it's usually only the async
operations that are queued, so we have to add in a bit more logic to
make the operation still appear to be synchronous, while actually
implementing it using the asynchronous task mechanisms.

```diff
commit b8e590ceb968fa87845b75d95ecc85214255e94f
Author: Jon Ludlam <jonathan.ludlam@citrix.com>
Date:   Thu Jun 12 23:23:20 2014 +0100

    Queue the VM.remove operation
    
    Signed-off-by: Jon Ludlam <jonathan.ludlam@citrix.com>

diff --git a/lib/xenops_server.ml b/lib/xenops_server.ml
index b470891..51f0b3d 100644
--- a/lib/xenops_server.ml
+++ b/lib/xenops_server.ml
@@ -1448,11 +1448,20 @@ and perform ?subtask (op: operation) (t: Xenops_task.t) : unit =
                | None -> one op
                | Some name -> Xenops_task.with_subtask t name (fun () -> one op)
 
-let queue_operation dbg id op =
+let queue_operation_int dbg id op =
        let task = Xenops_task.add tasks dbg (fun t -> perform op t; None) in
        Redirector.push id (op, task);
+       task
+
+let queue_operation dbg id op =
+       let task = queue_operation_int dbg id op in
        task.Xenops_task.id
 
+let queue_operation_and_wait dbg id op =
+       let from = Updates.last_id dbg updates in
+       let task = queue_operation_int dbg id op in
+       event_wait task ~from 1200.0 (task_finished_p task.Xenops_task.id)
+
 module PCI = struct
        open Pci
        module DB = PCI_DB
@@ -1670,7 +1679,7 @@ module VM = struct
        let add _ dbg x =
                Debug.with_thread_associated dbg (fun () -> add' x) ()
 
-       let remove _ dbg id = immediate_operation dbg id (Atomic(VM_remove id))
+       let remove _ dbg id = queue_operation_and_wait dbg id (Atomic (VM_remove id)) |> ignore
 
        let stat' x =
                debug "VM.stat %s" x;
```

And indeed, with [this queuing in place](https://github.com/xapi-project/xenopsd/pull/77) the problem doesn't happen even
with our fault injection code activated.

