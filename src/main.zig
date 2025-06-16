const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");

fn framebuffer_size_callback(_: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
    c.glViewport(0, 0, width, height);
}

fn processInputs(window: *c.GLFWwindow) void {
    if (c.glfwGetKey(window, c.GLFW_KEY_ESCAPE) == c.GLFW_PRESS)
        c.glfwSetWindowShouldClose(window, 1);
}

pub fn main() !void {
    // const loader = &c.glfwGetProcAddress;
    // const loader: ?*const fn (procname: [*c]const u8) callconv(.c) ?*const fn () callconv(.c) void = &c.glfwGetProcAddress;
    // const get_proc_address: ?*const fn (procname: [*c]const u8) callconv(.c) ?*anyopaque = @ptrCast(loader);

    var major: i32 = 0;
    var minor: i32 = 0;
    var rev: i32 = 0;
    c.glfwGetVersion(&major, &minor, &rev);
    std.debug.print("GLFW {}.{}.{}\n", .{ major, minor, rev });

    const init_result = c.glfwInit();
    std.debug.print("Init: {d}\n", .{init_result});
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    const width = 800;
    const height = 600;
    const maybeWindow: ?*c.GLFWwindow = c.glfwCreateWindow(width, height, "Sample Window", null, null);
    if (maybeWindow == null) {
        std.debug.print("Failed to create window\n", .{});
        c.glfwTerminate();
        return;
    }
    const window: *c.GLFWwindow = maybeWindow.?;
    c.glfwMakeContextCurrent(window);

    const get_proc_address: c.GLADloadproc = @ptrCast(&c.glfwGetProcAddress);
    const load_res = c.gladLoadGLLoader(get_proc_address);
    if (load_res == 0) {
        std.debug.print("Failed to initialize GLAD with code {d}\n", .{load_res});
        return;
    }

    c.glViewport(0, 0, width, height);
    _ = c.glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    while (c.glfwWindowShouldClose(window) != 1) {
        processInputs(window);

        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glfwPollEvents();
        c.glfwSwapBuffers(window);
    }
    c.glfwTerminate();
}
