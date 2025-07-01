const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");
const Allocator = std.mem.Allocator;
const Vec3f = @Vector(3, f32);
const Vec4f = @Vector(4, f32);
const Mat4f = [4]Vec4f;

const xaxis = Vec3f{ 1.0, 0.0, 0.0 };
const yaxis = Vec3f{ 0.0, 1.0, 0.0 };
const zaxis = Vec3f{ 0.0, 0.0, 1.0 };

// OpenGL objects struct to keep related data together
const OpenGLObjects = struct {
    VAO: c.GLuint,
    VBO: c.GLuint,
    num_vertices: c_ulonglong,
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
    std.debug.print("Buffering {d} points\n", .{vertices.len});
    c.glBufferData(c.GL_ARRAY_BUFFER, vertices_size, vertices.ptr, c.GL_STATIC_DRAW);

    // Configure vertex attributes
    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), null);
    c.glEnableVertexAttribArray(0);

    // Unbind
    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
    c.glBindVertexArray(0);

    c.glPolygonMode(c.GL_FRONT_AND_BACK, c.GL_LINE);

    return OpenGLObjects{
        .VAO = VAO,
        .VBO = VBO,
        .num_vertices = vertices.len,
        .shader_program = shader_program,
    };
}

fn setupViewport(window: *c.GLFWwindow, width: c_int, height: c_int) void {
    c.glViewport(0, 0, width, height);
    _ = c.glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
}

fn renderFrame(gl_objects: OpenGLObjects) !void {
    // Clear the screen
    c.glClearColor(0.2, 0.3, 0.3, 1.0);
    c.glClear(c.GL_COLOR_BUFFER_BIT);

    // Draw the triangle
    c.glUseProgram(gl_objects.shader_program);

    
    const time: f32 = @floatCast(c.glfwGetTime() * 4);

    const id: Mat4f = iden();
    // Apply a rotation around the Y axis
    const angle = degToRad(time * 30); // Rotate 30 degrees per second
    const rotation = rotate(angle, xaxis);
    const scale_half = scale(Vec3f{ 0.5, 0.5, 0.5 });
    const view4x4 = matmul(scale_half, matmul(id, rotation));
    // const up_x = 0.5 * std.math.sin(4*time) + 0.5;
    // std.debug.print("{d}\n", .{up_x});
    // const eye = Vec3f{ 0, 0, 1 };
    // const center = Vec3f{ 0.0, 0, 0.0 };
    // const up = Vec3f{0, 1, 0 };

    // const view4x4 = lookAt(eye, center, up);
    const view = flatten(view4x4);
    // std.debug.print("{d}\n", .{view4x4});

    const viewLoc = c.glGetUniformLocation(gl_objects.shader_program, "transform");
    if (viewLoc == -1)
        return error.CantRetrieveLoc;
    c.glUniformMatrix4fv(viewLoc, 1, c.GL_FALSE, &view);
    c.glBindVertexArray(gl_objects.VAO);
    checkGLError("Set Uniform");
    c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(gl_objects.num_vertices));
    checkGLError("Draw Arrays");
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
    const width = 600;
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
        try renderFrame(gl_objects);
        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }

    // Cleanup
    cleanup(gl_objects);
}

fn get_vertices(allocator: Allocator) ![]f32 {
    var shape_file = try std.fs.cwd().openFile("shape.csv", .{ .mode = .read_only });
    defer shape_file.close();
    const allFileBytes = try shape_file.readToEndAlloc(allocator, 10_000_000);
    defer allocator.free(allFileBytes);

    // The file is a list of triples float,float,float\n
    // Allocate memory for the vertices
    // Each line is like 50 characters, and we need 3 floats per line
    var heap_vertices = try std.ArrayList(f32).initCapacity(allocator, (50 / allFileBytes.len) * 3);

    var current_float_buff: [50]u8 = undefined;
    var i: usize = 0;

    for (allFileBytes) | char | {
        // std.debug.print("{c}\n", .{char});
        if (char == ',' or char == '\n') {
            const item = try std.fmt.parseFloat(f32, current_float_buff[0..i]);
            try heap_vertices.append(item);
            i = 0;
        }
        else if (char == ' ' or char == '\r') {}
        else {
            // We use a fixed buffer. It should never overflow.
            current_float_buff[i] = char;
            i += 1;
        }
    }
    if (i != 0) {
        const item = try std.fmt.parseFloat(f32, current_float_buff[0..i]);
        try heap_vertices.append(item);
    }

    // scale the vertices to be between -1 and 1.
    var max: f32 = -1e60;
    var min: f32 = 1e60;

    var result = heap_vertices.items;
    for (result) | unscaled  | {
        max = @max(max, unscaled);
        min = @min(min, unscaled);
    }
    const scale_factor = 1.5/(max-min);

    for (0..result.len) | idx | {
        // std.debug.print("{d} -> {d}\n", .{result[idx], scale * (result[idx]-min) - 0.75});
        result[idx] = scale_factor * (result[idx]-min) - 0.75;
        if (result[idx] > 1 or result[idx] < -1)
            return error.PointsOutOfRange;
    }

    // std.debug.print("Got {d} Points\n", .{result.len});
    return result;
}

fn iden() Mat4f {
    return .{
        .{ 1.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    };
}

fn cross(a: Vec3f, b: Vec3f) Vec3f {
    return .{
        a[1]*b[2] - a[2]*b[1],
        a[2]*b[0] - a[0]*b[2],
        a[0]*b[1] - a[1]*b[0],
    };
}

fn dot(a: Vec3f, b: Vec3f) f32 {
    return @reduce(.Add, a * b);
}

fn normalize(v: Vec3f) Vec3f {
    const v_mag: Vec3f = @splat(std.math.sqrt(dot(v, v)));
    return v / v_mag;
}

fn matmul(x: Mat4f, y: Mat4f) Mat4f {
    var result: Mat4f = undefined;
    for (0..4) |i| {
        for (0..4) |j| {
            result[i][j] = 0.0;
            for (0..4) |k| {
                result[i][j] += x[i][k] * y[k][j];
            }
        }
    }
    return result;
}

fn degToRad(degrees: f32) f32 {
    return degrees * (std.math.pi / 180.0);
}

fn translate(translation: Vec3f) Mat4f {
    return .{
        .{ 1.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ translation.x, translation.y, translation.z, 1.0 },
    };
}

fn rotate(angle_rad: f32, axis: Vec3f) Mat4f {
    const co = std.math.cos(angle_rad);
    const s = std.math.sin(angle_rad);
    const t = 1.0 - co;
    const x = axis[0];
    const y = axis[1];
    const z = axis[2];

    return .{
        .{ t*x*x + co,   t*x*y - s*z, t*x*z + s*y, 0.0 },
        .{ t*x*y + s*z, t*y*y + co,   t*y*z - s*x, 0.0 },
        .{ t*x*z - s*y, t*y*z + s*x, t*z*z + co,   0.0 },
        .{ 0.0,         0.0,         0.0,         1.0 },
    };
}

fn scale(scaling: Vec3f) Mat4f {
    const x, const y, const z = scaling;
    return .{
        .{ x, 0.0, 0.0, 0.0 },
        .{ 0.0, y, 0.0, 0.0 },
        .{ 0.0, 0.0, z, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    };
}

fn flatten(mat: Mat4f) [16]f32 {
    return @bitCast(mat);
}

fn get_vertex_shader() c_uint {
    const vertex_shader =
        \\#version 330 core
        \\layout (location = 0) in vec3 aPos;
        \\uniform mat4 transform;
        \\out vec3 vertColor;
        \\void main()
        \\{
        \\  gl_Position = transform * vec4(aPos, 1.0);
        \\  
        \\  //vertColor = gl_Position.zyx;
        \\  vertColor = vec3(1.0f, 0.5f, 0.2f);
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
        \\in vec3 vertColor;
        \\void main()
        \\{
        \\  FragColor = vec4(vertColor, 0.5f);
        \\}
    ;
        // \\  FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);

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
