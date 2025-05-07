module source.bridge.gl_utils;

import bindbc.opengl;
import std.stdio;
import std.file;
import std.string : toStringz, fromStringz;
import std.conv : to;

GLuint loadShader(GLenum type, const string filePath) {
    char[] source;
    try {
        source = cast(char[])std.file.read(filePath);
    } catch (Exception e) {
        stderr.writeln("Failed to read shader file: ", filePath, " - ", e.msg);
        return 0;
    }
    
    const(char)* sourcePtr = source.ptr;

    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &sourcePtr, null);
    glCompileShader(shader);

    GLint success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
        GLchar[512] infoLog;
        glGetShaderInfoLog(shader, infoLog.length, null, infoLog.ptr);
        stderr.writeln("Shader compilation error in '", filePath, "':\n", infoLog.ptr.fromStringz);
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

GLuint createShaderProgram(const string vertexPath, const string fragmentPath) {
    GLuint vertexShader = loadShader(GL_VERTEX_SHADER, vertexPath);
    if (vertexShader == 0) return 0;

    GLuint fragmentShader = loadShader(GL_FRAGMENT_SHADER, fragmentPath);
    if (fragmentShader == 0) {
        glDeleteShader(vertexShader);
        return 0;
    }

    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    glLinkProgram(program);

    GLint success;
    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (!success) {
        GLchar[512] infoLog;
        glGetProgramInfoLog(program, infoLog.length, null, infoLog.ptr);
        stderr.writeln("Shader program linking error:\n", infoLog.ptr.fromStringz);
        glDeleteShader(vertexShader);
        glDeleteShader(fragmentShader);
        glDeleteProgram(program);
        return 0;
    }

    glDeleteShader(vertexShader); // Shaders are linked, no longer needed
    glDeleteShader(fragmentShader);
    return program;
}

// Basic 3D math types (replace with a proper library like gl3n later)
struct Vec3 { float x, y, z; }
Vec3 vec3(float x, float y, float z) { return Vec3(x, y, z); }

struct Mat4 { 
    // Column-major order for OpenGL
    float[16] M = [
        1,0,0,0, 
        0,1,0,0, 
        0,0,1,0, 
        0,0,0,1
    ]; // Identity

    static Mat4 identity() { return Mat4(); }

    // Basic perspective projection (simplified)
    static Mat4 perspective(float fovRadians, float aspect, float near, float far) {
        import std.math : tan;
        Mat4 res;
        const float f = 1.0f / tan(fovRadians / 2.0f);
        res.M[0] = f / aspect;
        res.M[5] = f;
        res.M[10] = (far + near) / (near - far);
        res.M[11] = -1.0f;
        res.M[14] = (2.0f * far * near) / (near - far);
        res.M[15] = 0.0f;
        return res;
    }
    
    // Basic translation
    static Mat4 translation(float x, float y, float z) {
        Mat4 res;
        res.M[12] = x;
        res.M[13] = y;
        res.M[14] = z;
        return res;
    }
    
    // TODO: Add rotation, scaling, multiplication
}

// Matrix multiplication (basic)
Mat4 opBinary(string op : "*")(Mat4 a, Mat4 b) {
    Mat4 result;
    // This is a placeholder, proper matrix multiplication is more involved.
    // For now, just return 'a' to avoid making the code too long,
    // but this needs to be implemented correctly.
    // A proper math library like gl3n handles this.
    for (int i=0; i<16; ++i) result.M[i] = 0; // zero out
    for (int r = 0; r < 4; ++r) {
        for (int c = 0; c < 4; ++c) {
            for (int k = 0; k < 4; ++k) {
                result.M[c*4+r] += a.M[k*4+r] * b.M[c*4+k];
            }
        }
    }
    return result;
}

