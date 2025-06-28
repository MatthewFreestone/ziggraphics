const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");
const Allocator = std.mem.Allocator;

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
    const shader_program = get_shader_program();

    const malloc = std.heap.c_allocator;
    const vertices = get_vertices(malloc);

    var VAO: c.GLuint = 0;
    var VBO: c.GLuint = 0;

    c.glGenVertexArrays(1, &VAO);
    c.glGenBuffers(1, &VBO);

    c.glBindVertexArray(VAO);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, VBO);
    c.glBufferData(c.GL_ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, c.GL_STATIC_DRAW);

    // tell opengl how to interpret the result of the vertex shader
    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), null);
    c.glEnableVertexAttribArray(0);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
    c.glBindVertexArray(0);

    checkGLError("after VAO setup");

    _ = c.glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    while (c.glfwWindowShouldClose(window) != 1) {
        processInputs(window);

        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glUseProgram(shader_program);
        c.glBindVertexArray(VAO);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }

    c.glDeleteVertexArrays(1, &VAO);
    c.glDeleteBuffers(1, &VBO);
    c.glDeleteProgram(shader_program);
    c.glfwTerminate();
}

fn get_vertices(_: Allocator) [9]f32 {
    const vertices = [_]f32{ -0.5, -0.5, 0.0, 0.5, -0.5, 0.0, 0.0, 0.5, 0.0 };
    return vertices;
}

fn get_vertex_shader() c_uint {
    // const vertex_shader: *const [120: 0]c.GLchar =
    const vertex_shader =
        \\#version 330 core
        \\layout (location = 0) in vec3 aPos;
        \\
        \\void main()
        \\{
        \\  gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
        \\}
    ;
    const shader_ptr = c.glCreateShader(c.GL_VERTEX_SHADER);
    c.glShaderSource(shader_ptr, 1, @ptrCast(&vertex_shader), null);
    c.glCompileShader(shader_ptr);
    var success: i32 = 0;
    var infoLog: [512]u8 = undefined;
    c.glGetShaderiv(shader_ptr, c.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        c.glGetShaderInfoLog(shader_ptr, infoLog.len, null, &infoLog);
        std.debug.print("ERROR::SHADER::VERTEX::COMPILATION_FAILED {s}\n", .{infoLog});
    }
    return shader_ptr;
}

fn get_fragment_shader() c_uint {
    const fragment_shader =
        \\#version 330 core
        \\out vec4 FragColor;
        \\
        \\void main()
        \\{
        \\  FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
        \\}
    ;
    const shader_ptr = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    c.glShaderSource(shader_ptr, 1, @ptrCast(&fragment_shader), null);
    c.glCompileShader(shader_ptr);
    var success: i32 = 0;
    var infoLog: [512]u8 = undefined;
    c.glGetShaderiv(shader_ptr, c.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        c.glGetShaderInfoLog(shader_ptr, infoLog.len, null, &infoLog);
        std.debug.print("ERROR::SHADER::FRAGMENT::COMPILATION_FAILED {s}\n", .{infoLog});
    }
    return shader_ptr;
}

fn get_shader_program() c_uint {
    const vertex = get_vertex_shader();
    const fragment = get_fragment_shader();
    const shader_program = c.glCreateProgram();
    c.glAttachShader(shader_program, vertex);
    c.glAttachShader(shader_program, fragment);
    c.glLinkProgram(shader_program);
    var success: i32 = 0;
    var infoLog: [512]u8 = undefined;
    c.glGetProgramiv(shader_program, c.GL_LINK_STATUS, &success);
    if (success == 0) {
        c.glGetProgramInfoLog(shader_program, 512, null, &infoLog);
        std.debug.print("ERROR::SHADER::PROGRAM::COMPILATION_FAILED {s}\n", .{infoLog});
    }

    defer c.glDeleteShader(vertex);
    defer c.glDeleteShader(fragment);

    return shader_program;
}

fn checkGLError(location: []const u8) void {
    const err = c.glGetError();
    if (err != c.GL_NO_ERROR) {
        std.debug.print("OpenGL error at {s}: 0x{X}\n", .{ location, err });
    }
}
