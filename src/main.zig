const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");
const Allocator = std.mem.Allocator;

// OpenGL objects struct to keep related data together
const OpenGLObjects = struct {
    VAO: c.GLuint,
    VBO: c.GLuint,
    shader_program: c.GLuint,
};

fn framebuffer_size_callback(_: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
    c.glViewport(0, 0, width, height);
}

fn processInputs(window: *c.GLFWwindow) void {
    if (c.glfwGetKey(window, c.GLFW_KEY_ESCAPE) == c.GLFW_PRESS)
        c.glfwSetWindowShouldClose(window, 1);
}

fn initializeGLFW() !void {
    var major: i32 = 0;
    var minor: i32 = 0;
    var rev: i32 = 0;
    c.glfwGetVersion(&major, &minor, &rev);
    std.debug.print("GLFW {}.{}.{}\n", .{ major, minor, rev });

    const init_result = c.glfwInit();
    std.debug.print("Init: {d}\n", .{init_result});
    if (init_result == 0) {
        return error.GLFWInitFailed;
    }

    // Set OpenGL version and profile
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
}

fn createWindow(width: c_int, height: c_int, title: [*c]const u8) !*c.GLFWwindow {
    const maybeWindow: ?*c.GLFWwindow = c.glfwCreateWindow(width, height, title, null, null);
    if (maybeWindow == null) {
        std.debug.print("Failed to create window\n", .{});
        c.glfwTerminate();
        return error.WindowCreationFailed;
    }
    const window: *c.GLFWwindow = maybeWindow.?;
    c.glfwMakeContextCurrent(window);
    return window;
}

fn initializeGLAD() !void {
    const get_proc_address: c.GLADloadproc = @ptrCast(&c.glfwGetProcAddress);
    const load_res = c.gladLoadGLLoader(get_proc_address);
    if (load_res == 0) {
        std.debug.print("Failed to initialize GLAD with code {d}\n", .{load_res});
        return error.GLADInitFailed;
    }
}

fn setupVertexData(allocator: Allocator) !OpenGLObjects {
    const vertices = try get_vertices(allocator);
    defer allocator.free(vertices); // Clean up the vertices after OpenGL copies them

    const shader_program = get_shader_program();

    var VAO: c.GLuint = 0;
    var VBO: c.GLuint = 0;

    c.glGenVertexArrays(1, &VAO);
    c.glGenBuffers(1, &VBO);

    // Bind VAO first
    c.glBindVertexArray(VAO);

    // Set up VBO
    c.glBindBuffer(c.GL_ARRAY_BUFFER, VBO);
    const vertices_size: c_longlong = @intCast(vertices.len * @sizeOf(f32));
    c.glBufferData(c.GL_ARRAY_BUFFER, vertices_size, vertices.ptr, c.GL_STATIC_DRAW);

    // Configure vertex attributes
    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), null);
    c.glEnableVertexAttribArray(0);

    // Unbind
    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
    c.glBindVertexArray(0);

    return OpenGLObjects{
        .VAO = VAO,
        .VBO = VBO,
        .shader_program = shader_program,
    };
}

fn setupViewport(window: *c.GLFWwindow, width: c_int, height: c_int) void {
    c.glViewport(0, 0, width, height);
    _ = c.glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
}

fn renderFrame(gl_objects: OpenGLObjects) void {
    // Clear the screen
    c.glClearColor(0.2, 0.3, 0.3, 1.0);
    c.glClear(c.GL_COLOR_BUFFER_BIT);

    // Draw the triangle
    c.glUseProgram(gl_objects.shader_program);
    c.glBindVertexArray(gl_objects.VAO);
    c.glDrawArrays(c.GL_TRIANGLES, 0, 3);
}

fn cleanup(gl_objects: OpenGLObjects) void {
    c.glDeleteVertexArrays(1, &gl_objects.VAO);
    c.glDeleteBuffers(1, &gl_objects.VBO);
    c.glDeleteProgram(gl_objects.shader_program);
    c.glfwTerminate();
}

fn checkGLError(location: []const u8) void {
    const err = c.glGetError();
    if (err != c.GL_NO_ERROR) {
        std.debug.print("OpenGL error at {s}: 0x{X}\n", .{ location, err });
    }
}

pub fn main() !void {
    const width = 800;
    const height = 600;

    // Initialize GLFW
    try initializeGLFW();

    // Create window
    const window = try createWindow(width, height, "Sample Window");

    // Initialize GLAD
    try initializeGLAD();

    // Setup OpenGL objects
    const malloc = std.heap.c_allocator;
    const gl_objects = try setupVertexData(malloc);
    checkGLError("after vertex data setup");

    // Setup viewport and callbacks
    setupViewport(window, width, height);

    // Main render loop
    while (c.glfwWindowShouldClose(window) != 1) {
        processInputs(window);
        renderFrame(gl_objects);
        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }

    // Cleanup
    cleanup(gl_objects);
}

fn get_vertices(allocator: Allocator) ![]f32 {
    const vertices = [_]f32{ -0.5, -0.5, 0.0, 0.5, -0.5, 0.0, 0.0, 0.5, 0.0 };

    // Allocate memory for the vertices
    const heap_vertices = try allocator.alloc(f32, vertices.len);

    // Copy the vertices to heap memory
    @memcpy(heap_vertices, &vertices);
    return heap_vertices;
}

fn get_vertex_shader() c_uint {
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
