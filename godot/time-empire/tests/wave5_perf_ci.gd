extends SceneTree
## Real frames from the GitHub-hosted CI's virtualized/software graphics stack.
## These numbers are NOT performance measurements on a dedicated consumer GPU.

func _init() -> void:
    call_deferred("_capture")

func _capture() -> void:
    root.size = Vector2i(1280, 720)
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        push_error("Wave 5 benchmark cannot load main scene")
        quit(1)
        return
    var game := packed.instantiate() as Node3D
    root.add_child(game)
    for frame in range(35):
        await process_frame
    var times: Array[float] = []
    var last: int = Time.get_ticks_usec()
    for frame in range(100):
        await RenderingServer.frame_post_draw
        var now: int = Time.get_ticks_usec()
        times.append(float(now - last) / 1000.0)
        last = now
    times.sort()
    var total: float = 0.0
    for value in times:
        total += value
    var p95: float = times[clampi(int(ceil(float(times.size()-1) * 0.95)),0,times.size()-1)]
    var sample := {
        "schema": "osgard.wave5.ci-software-render-benchmark.v1",
        "game": "time-empire",
        "run_context": "GitHub-hosted Linux + Xvfb + Mesa. NOT gaming-PC FPS",
        "measurements": times.size(),
        "mean_frame_ms": total / maxf(float(times.size()),1.0),
        "p95_frame_ms": p95,
        "renderer": RenderingServer.get_current_rendering_method(),
        "driver": RenderingServer.get_current_rendering_driver_name(),
        "adapter": RenderingServer.get_video_adapter_name(),
        "os": OS.get_name(),
        "cpu": OS.get_processor_name(),
        "viewport": "1280x720",
        "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
    }
    var folder: String = ProjectSettings.globalize_path("res://benchmark-ci")
    if DirAccess.make_dir_recursive_absolute(folder) != OK:
        push_error("Cannot create performance artifact directory")
        quit(1)
        return
    var path := folder.path_join("time-empire-ci-performance.json")
    var out := FileAccess.open(path, FileAccess.WRITE)
    if out == null:
        push_error("Cannot write performance JSON")
        quit(1)
        return
    out.store_string(JSON.stringify(sample, "  "))
    out.close()
    print("OSGARD_CI_SOFTWARE_BENCHMARK: ", JSON.stringify(sample))
    game.queue_free()
    quit(0)