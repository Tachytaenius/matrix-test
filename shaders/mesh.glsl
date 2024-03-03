varying vec3 fragmentNormalModelSpace;

#ifdef VERTEX

uniform mat4 modelToWorld1;
uniform mat4 world1ToWorld2;
uniform float world1VsWorld2Lerp;
uniform mat4 worldLerpedToScreen;

attribute vec3 VertexNormal;

vec4 position(mat4 loveTransform, vec4 modelSpaceVertexPos) {
	fragmentNormalModelSpace = VertexNormal;
	vec4 world1SpaceVertexPos = modelToWorld1 * modelSpaceVertexPos;
	// Do I need to do the / w?
	vec4 world2SpaceVertexPos = world1ToWorld2 * world1SpaceVertexPos;
	// Do I need to do the / w?
	vec4 worldLerpedVertexPos = mix(world1SpaceVertexPos, world2SpaceVertexPos, world1VsWorld2Lerp);
	// Do I need to do the / w?
	return worldLerpedToScreen * worldLerpedVertexPos;
}

#endif

#ifdef PIXEL

vec4 effect(vec4 colour, sampler2D image, vec2 textureCoords, vec2 windowCoords) {
	return vec4(fragmentNormalModelSpace / 2.0 + 0.5, 1.0);
}

#endif
