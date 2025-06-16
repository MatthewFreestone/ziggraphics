const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
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

    const window: ?*c.GLFWwindow = c.glfwCreateWindow(800, 600, "Sample Window", null, null);
    if (window == null) {
        std.debug.print("Failed to create window\n", .{});
        c.glfwTerminate();
        return;
    }
    c.glfwMakeContextCurrent(window);

    const get_proc_address: c.GLADloadproc = @ptrCast(&c.glfwGetProcAddress);
    const load_res = c.gladLoadGLLoader(get_proc_address);
    if (load_res == 0) {
        std.debug.print("Failed to initialize GLAD with code {d}\n", .{load_res});
        return;
    }

    c.glViewport(0, 0, 800, 600);
}

const std = @import("std");
