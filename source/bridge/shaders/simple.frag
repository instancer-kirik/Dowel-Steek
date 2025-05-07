#version 330 core

in vec3 nossoColor; // Received from vertex shader

out vec4 FragColor;

void main() {
    FragColor = vec4(nossoColor, 1.0);
}

