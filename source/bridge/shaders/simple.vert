#version 330 core

layout (location = 0) in vec3 aPos;  // Vertex position attribute
layout (location = 1) in vec3 aColor; // Vertex color attribute (optional for now)

out vec3 nossoColor; // Pass color to fragment shader

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main() {
    gl_Position = projection * view * model * vec4(aPos, 1.0);
    nossoColor = aColor; // Or a fixed color if not using vertex colors yet
}