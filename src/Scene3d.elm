module Scene3d exposing
    ( toHtml
    , unlit, sunny, cloudy, office
    , Entity
    , point, lineSegment, triangle, facet, quad, block, sphere, cylinder, cone
    , triangleWithShadow, facetWithShadow, quadWithShadow, blockWithShadow, sphereWithShadow, cylinderWithShadow, coneWithShadow
    , mesh, meshWithShadow
    , group, nothing
    , rotateAround, translateBy, translateIn, scaleAbout, mirrorAcross
    , Background, transparentBackground, whiteBackground, blackBackground, backgroundColor, translucentBackground
    , Antialiasing
    , noAntialiasing, multisampling, supersampling
    , Lights
    , noLights, oneLight, twoLights, threeLights, fourLights, fiveLights, sixLights, sevenLights, eightLights
    , Exposure
    , exposureValue, maxLuminance, photographicExposure
    , ToneMapping
    , noToneMapping, reinhardToneMapping, reinhardPerChannelToneMapping, hableFilmicToneMapping
    , placeIn, relativeTo
    , triangleShadow, quadShadow, blockShadow, sphereShadow, cylinderShadow, coneShadow, meshShadow
    , composite, toWebGLEntities
    )

{-| Top-level functionality for rendering a 3D scene.

Note that the way `elm-3d-scene` is designed, functions in this module are
generally 'cheap' and can safely be used in your `view` function directly. For
example, you can safely have logic in your `view` function that enables and
disables lights, moves objects around by translating/rotating/mirroring them,
or even changes the material used to render a particular object with. In
contrast, creating meshes using the functions in the [`Mesh`](Scene3d-Mesh)
module is 'expensive'; meshes should generally be created once and then stored
in your model.

@docs toHtml


## Presets

These 'preset' scenes are simplified versions of `toHtml` that let you get
started quickly with some reasonable defaults. Scene lighting, exposure and
white balance will generally be set for you. However, in all cases you still
have to specify a camera position/orientation, a clip depth, a background color
and the dimensions with which to render the scene.

@docs unlit, sunny, cloudy, office


# Entities

@docs Entity


## Basic shapes

`elm-3d-scene` includes a handful of basic shapes which you can draw directly
without having to create and store a separate [`Mesh`](Scene3d-Mesh). In
general, for most of the basic shapes you can specify whether or not it should
cast a shadow (assuming there is shadow-casting light in the scene!) and can
specify a material to use. However, different shapes support different kinds of
materials:

  - `quad`s and `sphere`s support all materials
  - `block`s, `cylinder`s, `cone`s and `facet`s only support uniform
    (non-textured) materials
  - `point`s, `lineSegment`s and `triangle`s only support plain materials
    (solid colors or emissive materials)

Note that you _could_ render complex shapes by (for example) mapping
`Scene3d.triangle` over a list of triangles, but this would be inefficient; if
you have a large number of triangles it is much better to create a mesh using
[`Mesh.triangles`](Scene3d-Mesh#triangles) or similar, store that mesh either in
your model or as a top-level constant, and then render it using [`Scene3d.mesh`](#mesh).
For up to a few dozen individual entities (points, line segments, triangles etc)
it should be fine to use these convenience functions, but for much more than
that you will likely want to switch to using a proper mesh for efficiency.

@docs point, lineSegment, triangle, facet, quad, block, sphere, cylinder, cone


## Shapes with shadows

These functions behave just like their corresponding non-`WithShadow` versions
but make the given object cast a shadow (or perhaps multiple shadows, if there
are multiple shadow-casting lights in the scene). Note that no shadows will
appear if there are no shadow-casting lights!

@docs triangleWithShadow, facetWithShadow, quadWithShadow, blockWithShadow, sphereWithShadow, cylinderWithShadow, coneWithShadow


## Meshes

@docs mesh, meshWithShadow


## Grouping and toggling

@docs group, nothing


## Transformations

These transformations are 'cheap' in that they don't actually transform the
underlying mesh; under the hood they use a WebGL [transformation matrix](https://learnopengl.com/Getting-started/Transformations)
to change where that mesh gets rendered.

@docs rotateAround, translateBy, translateIn, scaleAbout, mirrorAcross


# Background

@docs Background, transparentBackground, whiteBackground, blackBackground, backgroundColor, translucentBackground


# Antialiasing

@docs Antialiasing

@docs noAntialiasing, multisampling, supersampling


# Lighting

@docs Lights

The following functions let you set up lighting using up to eight lights. Note
that any light past the fourth must be constructed using [`Scene3d.neverCastsShadows`](#neverCastsShadows).

@docs noLights, oneLight, twoLights, threeLights, fourLights, fiveLights, sixLights, sevenLights, eightLights


## Exposure

@docs Exposure

@docs exposureValue, maxLuminance, photographicExposure


## Tone mapping

@docs ToneMapping

@docs noToneMapping, reinhardToneMapping, reinhardPerChannelToneMapping, hableFilmicToneMapping


# Advanced

You're unlikely to need these functions right away but they can be very useful
when setting up more complex scenes.


## Coordinate conversions

@docs placeIn, relativeTo


## Standalone shadows

In some cases you might want to render the shadow of some object without
rendering the object itself. This can let you do things like render a high-poly
door while rendering its shadow using a simpler approximate shape like a quad or
rectangular block to reduce rendering time (rendering shadows of complex
meshes can be expensive).

Note that if you do something like this then you will need to be careful to make
sure that the approximate object fits _inside_ the actual mesh being rendered -
otherwise you might end up with the object effectively shadowing itself.

@docs triangleShadow, quadShadow, blockShadow, sphereShadow, cylinderShadow, coneShadow, meshShadow


## Customized rendering

@docs composite, toWebGLEntities

-}

import Angle exposing (Angle)
import Axis3d exposing (Axis3d)
import Bitwise
import Block3d exposing (Block3d)
import BoundingBox3d exposing (BoundingBox3d)
import Camera3d exposing (Camera3d)
import Color exposing (Color)
import Color.Transparent
import Cone3d exposing (Cone3d)
import Cylinder3d exposing (Cylinder3d)
import Direction3d exposing (Direction3d)
import Duration exposing (Duration)
import Frame3d exposing (Frame3d)
import Geometry.Interop.LinearAlgebra.Frame3d as Frame3d
import Geometry.Interop.LinearAlgebra.Point3d as Point3d
import Html exposing (Html)
import Html.Attributes
import Html.Keyed
import Illuminance exposing (Illuminance)
import Length exposing (Length, Meters)
import LineSegment3d exposing (LineSegment3d)
import Luminance exposing (Luminance)
import LuminousFlux exposing (LuminousFlux)
import Math.Matrix4 exposing (Mat4)
import Math.Vector2 exposing (Vec2)
import Math.Vector3 exposing (Vec3)
import Math.Vector4 exposing (Vec4)
import Pixels exposing (Pixels, inPixels)
import Plane3d exposing (Plane3d)
import Point3d exposing (Point3d)
import Quantity exposing (Quantity(..))
import Rectangle2d
import Scene3d.ColorConversions as ColorConversions
import Scene3d.Entity as Entity
import Scene3d.Light as Light exposing (Chromaticity, Light)
import Scene3d.Material as Material exposing (Material)
import Scene3d.Mesh as Mesh exposing (Mesh)
import Scene3d.Transformation as Transformation exposing (Transformation)
import Scene3d.Types as Types exposing (Bounds, DrawFunction, LightMatrices, LinearRgb(..), Material(..), Node(..))
import Sphere3d exposing (Sphere3d)
import Temperature exposing (Temperature)
import Triangle3d exposing (Triangle3d)
import Vector3d exposing (Vector3d)
import Viewpoint3d exposing (Viewpoint3d)
import WebGL
import WebGL.Matrices as WebGL
import WebGL.Settings
import WebGL.Settings.Blend as Blend
import WebGL.Settings.DepthTest as DepthTest
import WebGL.Settings.StencilTest as StencilTest
import WebGL.Texture exposing (Texture)



----- ENTITIES -----


{-| An `Entity` is a shape or group of shapes in a scene.
-}
type alias Entity coordinates =
    Types.Entity coordinates


{-| A dummy entity for which nothing will be drawn.
-}
nothing : Entity coordinates
nothing =
    Entity.empty


{-| Draw a single point as a circular dot with the given radius.
-}
point :
    { radius : Quantity Float Pixels }
    -> Material.Plain coordinates
    -> Point3d Meters coordinates
    -> Entity coordinates
point { radius } givenMaterial givenPoint =
    Entity.point radius givenMaterial givenPoint


{-| Draw a single line segment.
-}
lineSegment : Material.Plain coordinates -> LineSegment3d Meters coordinates -> Entity coordinates
lineSegment givenMaterial givenLineSegment =
    Entity.lineSegment givenMaterial givenLineSegment


dummyMaterial : Material coordinates attributes
dummyMaterial =
    Material.color (Color.fromRGB ( 0, 0, 0 ))


{-| Draw a single triangle.
-}
triangle :
    Material.Plain coordinates
    -> Triangle3d Meters coordinates
    -> Entity coordinates
triangle givenMaterial givenTriangle =
    facet (Material.plain givenMaterial) givenTriangle


{-| -}
triangleWithShadow :
    Material.Plain coordinates
    -> Triangle3d Meters coordinates
    -> Entity coordinates
triangleWithShadow givenMaterial givenTriangle =
    facetWithShadow (Material.plain givenMaterial) givenTriangle


{-| -}
triangleShadow : Triangle3d Meters coordinates -> Entity coordinates
triangleShadow givenTriangle =
    Entity.triangle False True dummyMaterial givenTriangle


{-| Like `Scene3d.triangle`, but also generates a normal vector so that matte
and physically-based materials (materials that require lighting) can be used.
-}
facet :
    Material.Uniform coordinates
    -> Triangle3d Meters coordinates
    -> Entity coordinates
facet givenMaterial givenTriangle =
    Entity.triangle True False givenMaterial givenTriangle


{-| -}
facetWithShadow :
    Material.Uniform coordinates
    -> Triangle3d Meters coordinates
    -> Entity coordinates
facetWithShadow givenMaterial givenTriangle =
    Entity.triangle True True givenMaterial givenTriangle


{-| Draw a 'quad' such as a rectangle, rhombus or parallelogram by providing its
four vertices in counterclockwise order.

Normal vectors will be automatically computed at each vertex which are
perpendicular to the two adjoining edges. (The four vertices should usually
be coplanar, in which case all normal vectors will be the same.) The four
vertices will also be given the UV (texture) coordinates (0,0), (1,0), (1,1)
and (0,1) respectively; this means that if you specify vertices counterclockwise
from the bottom left corner of a rectangle, a texture will map onto the
rectangle basically the way you would expect.

-}
quad :
    Material.Textured coordinates
    -> Point3d Meters coordinates
    -> Point3d Meters coordinates
    -> Point3d Meters coordinates
    -> Point3d Meters coordinates
    -> Entity coordinates
quad givenMaterial p1 p2 p3 p4 =
    Entity.quad True False givenMaterial p1 p2 p3 p4


{-| -}
quadWithShadow :
    Material.Textured coordinates
    -> Point3d Meters coordinates
    -> Point3d Meters coordinates
    -> Point3d Meters coordinates
    -> Point3d Meters coordinates
    -> Entity coordinates
quadWithShadow givenMaterial p1 p2 p3 p4 =
    Entity.quad True True givenMaterial p1 p2 p3 p4


{-| -}
quadShadow :
    Point3d Meters coordinates
    -> Point3d Meters coordinates
    -> Point3d Meters coordinates
    -> Point3d Meters coordinates
    -> Entity coordinates
quadShadow p1 p2 p3 p4 =
    Entity.quad False True dummyMaterial p1 p2 p3 p4


{-| Draw a sphere using the [`Sphere3d`](https://package.elm-lang.org/packages/ianmackenzie/elm-geometry/latest/Sphere3d)
type from `elm-geometry`.

The sphere will have texture (UV) coordinates based on an [equirectangular
projection](https://wiki.panotools.org/Equirectangular_Projection) where
positive Z is up. This sounds complex but really just means that U corresponds
to angle around the sphere and V corresponds to angle up the sphere, similar to
the diagrams shown [here](https://en.wikipedia.org/wiki/Spherical_coordinate_system)
except that V is measured up from the bottom (negative Z) instead of down from
the top (positive Z).

Note that this projection, while simple, means that the texture used will get
'squished' near the poles of the sphere.

-}
sphere : Material.Textured coordinates -> Sphere3d Meters coordinates -> Entity coordinates
sphere givenMaterial givenSphere =
    Entity.sphere True False givenMaterial givenSphere


{-| -}
sphereWithShadow : Material.Textured coordinates -> Sphere3d Meters coordinates -> Entity coordinates
sphereWithShadow givenMaterial givenSphere =
    Entity.sphere True True givenMaterial givenSphere


{-| -}
sphereShadow : Sphere3d Meters coordinates -> Entity coordinates
sphereShadow givenSphere =
    Entity.sphere False True dummyMaterial givenSphere


{-| Draw a rectangular block using the [`Block3d`](https://package.elm-lang.org/packages/ianmackenzie/elm-geometry/latest/Block3d)
type from `elm-geometry`.
-}
block : Material.Uniform coordinates -> Block3d Meters coordinates -> Entity coordinates
block givenMaterial givenBlock =
    Entity.block True False givenMaterial givenBlock


{-| -}
blockWithShadow : Material.Uniform coordinates -> Block3d Meters coordinates -> Entity coordinates
blockWithShadow givenMaterial givenBlock =
    Entity.block True True givenMaterial givenBlock


{-| -}
blockShadow : Block3d Meters coordinates -> Entity coordinates
blockShadow givenBlock =
    Entity.block False True dummyMaterial givenBlock


{-| Draw a cylinder using the [`Cylinder3d`](https://package.elm-lang.org/packages/ianmackenzie/elm-geometry/latest/Cylinder3d)
type from `elm-geometry`.
-}
cylinder : Material.Uniform coordinates -> Cylinder3d Meters coordinates -> Entity coordinates
cylinder givenMaterial givenCylinder =
    Entity.cylinder True False givenMaterial givenCylinder


{-| -}
cylinderWithShadow : Material.Uniform coordinates -> Cylinder3d Meters coordinates -> Entity coordinates
cylinderWithShadow givenMaterial givenCylinder =
    Entity.cylinder True True givenMaterial givenCylinder


{-| -}
cylinderShadow : Cylinder3d Meters coordinates -> Entity coordinates
cylinderShadow givenCylinder =
    Entity.cylinder False True dummyMaterial givenCylinder


{-| Draw a cone using the [`Cone3d`](https://package.elm-lang.org/packages/ianmackenzie/elm-geometry/latest/Cone3d)
type from `elm-geometry`.
-}
cone : Material.Uniform coordinates -> Cone3d Meters coordinates -> Entity coordinates
cone givenMaterial givenCone =
    Entity.cone True False givenMaterial givenCone


{-| -}
coneWithShadow : Material.Uniform coordinates -> Cone3d Meters coordinates -> Entity coordinates
coneWithShadow givenMaterial givenCone =
    Entity.cone True True givenMaterial givenCone


{-| -}
coneShadow : Cone3d Meters coordinates -> Entity coordinates
coneShadow givenCone =
    Entity.cone False True dummyMaterial givenCone


{-| Draw the given mesh (shape) with the given material. Check out the [`Mesh`](Scene3d-Mesh)
and [`Material`](Scene3d-Material) modules for how to define meshes and
materials. Note that the mesh and material types must line up, and this is
checked by the compiler; for example, a textured material that requires UV
coordinates can only be used on a mesh that includes UV coordinates!

If you want to also draw the shadow of a given object, you'll need to use
[`meshWithShadow`](#meshWithShadow).

-}
mesh : Material coordinates attributes -> Mesh coordinates attributes -> Entity coordinates
mesh givenMaterial givenMesh =
    Entity.mesh givenMaterial givenMesh


{-| Draw a mesh and its shadow. To render an object with a shadow, you would
generally do something like:

    -- Construct the mesh/shadow in init/update and then
    -- save them in your model:

    objectMesh =
        -- Construct a mesh using Mesh.triangles,
        -- Mesh.indexedFaces etc.

    objectShadow =
        Mesh.shadow objectMesh

    -- Later, render the mesh/shadow in your view function:

    objectMaterial =
        -- Construct a material using Material.color,
        -- Material.metal etc.

    entity =
        Scene3d.meshWithShadow
            objectMesh
            objectMaterial
            objectShadow

-}
meshWithShadow :
    Material coordinates attributes
    -> Mesh coordinates attributes
    -> Mesh.Shadow coordinates
    -> Entity coordinates
meshWithShadow givenMaterial givenMesh givenShadow =
    group [ Entity.mesh givenMaterial givenMesh, Entity.shadow givenShadow ]


{-| Group a list of entities into a single entity. This combined entity can then
be transformed, grouped with other entities, etc.
-}
group : List (Entity coordinates) -> Entity coordinates
group entities =
    Entity.group entities


{-| -}
meshShadow : Mesh.Shadow coordinates -> Entity coordinates
meshShadow givenShadow =
    Entity.shadow givenShadow


{-| Rotate an entity around a given axis by a given angle.
-}
rotateAround : Axis3d Meters coordinates -> Angle -> Entity coordinates -> Entity coordinates
rotateAround axis angle entity =
    Entity.rotateAround axis angle entity


{-| Translate (move) an entity by a given displacement vector.
-}
translateBy : Vector3d Meters coordinates -> Entity coordinates -> Entity coordinates
translateBy displacement entity =
    Entity.translateBy displacement entity


{-| Translate an entity in a given direction by a given distance.
-}
translateIn : Direction3d coordinates -> Length -> Entity coordinates -> Entity coordinates
translateIn direction distance entity =
    Entity.translateIn direction distance entity


{-| Scale an entity about a given point by a given scale. The given point will
remain fixed in place and all other points on the entity will be stretched away
from that point (or contract towards that point, if the scale is less than one).

`elm-3d-scene` tries very hard to do the right thing here even if you use a
_negative_ scale factor, but that flips the mesh inside out so I don't really
recommend it.

-}
scaleAbout : Point3d Meters coordinates -> Float -> Entity coordinates -> Entity coordinates
scaleAbout centerPoint scale entity =
    Entity.scaleAbout centerPoint scale entity


{-| Mirror an entity across a plane.
-}
mirrorAcross : Plane3d Meters coordinates -> Entity coordinates -> Entity coordinates
mirrorAcross plane entity =
    Entity.mirrorAcross plane entity


{-| Take an entity that is defined in a local coordinate system and convert it
to global coordinates. This can be useful if you have some entities which are
defined in some local coordinate system like inside a car, and you want to
render them within a larger world.
-}
placeIn : Frame3d Meters coordinates { defines : localCoordinates } -> Entity localCoordinates -> Entity coordinates
placeIn frame entity =
    Entity.placeIn frame entity


{-| Take an entity that is defined in global coordinates and convert into a
local coordinate system. This is even less likely to be useful than `placeIn`,
but may be useful if you are (for example) rendering an office scene (and
working primarily in local room coordinates) but want to incorporate some entity
defined in global coordinates like a bird flying past the window.
-}
relativeTo : Frame3d Meters coordinates { defines : localCoordinates } -> Entity coordinates -> Entity localCoordinates
relativeTo frame entity =
    Entity.relativeTo frame entity


{-| A `Lights` value represents the set of all lights in a scene. There are a
couple of current limitations to note in `elm-3d-scene`:

  - No more than eight lights can exist in the scene.
  - Only the first four of those lights can cast shadows.

The reason there is a separate `Lights` type, instead of just using a list of
`Light` values, is so that the type system can be used to guarantee these
constraints are satisfied.

-}
type Lights coordinates
    = SingleUnshadowedPass LightMatrices
    | SingleShadowedPass LightMatrices
    | MultiplePasses (List Mat4) LightMatrices


singleLight : Light coordinates castsShadows -> Mat4
singleLight (Types.Light light) =
    Math.Matrix4.fromRecord
        { m11 = light.x
        , m21 = light.y
        , m31 = light.z
        , m41 = light.type_
        , m12 = light.r
        , m22 = light.g
        , m32 = light.b
        , m42 = light.parameter
        , m13 = 0
        , m23 = 0
        , m33 = 0
        , m43 = 0
        , m14 = 0
        , m24 = 0
        , m34 = 0
        , m44 = 0
        }


lightPair : Light coordinates firstCastsShadows -> Light coordinates secondCastsShadows -> Mat4
lightPair (Types.Light first) (Types.Light second) =
    Math.Matrix4.fromRecord
        { m11 = first.x
        , m21 = first.y
        , m31 = first.z
        , m41 = first.type_
        , m12 = first.r
        , m22 = first.g
        , m32 = first.b
        , m42 = first.parameter
        , m13 = second.x
        , m23 = second.y
        , m33 = second.z
        , m43 = second.type_
        , m14 = second.r
        , m24 = second.g
        , m34 = second.b
        , m44 = second.parameter
        }


lightingDisabled : ( LightMatrices, Vec4 )
lightingDisabled =
    ( { lights12 = lightPair Light.disabled Light.disabled
      , lights34 = lightPair Light.disabled Light.disabled
      , lights56 = lightPair Light.disabled Light.disabled
      , lights78 = lightPair Light.disabled Light.disabled
      }
    , Math.Vector4.vec4 0 0 0 0
    )


allLightsEnabled : Vec4
allLightsEnabled =
    Math.Vector4.vec4 1 1 1 1


{-| No lights at all! You don't need lights if you're only using materials
like [`color`](Material#color) or [`emissive`](Material#emissive) (since those
materials don't react to external light anyways). But in that case it might be
simplest to use [`Scene3d.unlit`](Scene3d#unlit) instead of [`Scene3d.toHtml`](Scene3d#toHtml)
so that you don't have to explicitly provide a `Lights` value at all.
-}
noLights : Lights coordinates
noLights =
    SingleUnshadowedPass (Tuple.first lightingDisabled)


lightCastsShadows : Light coordinates castsShadows -> Bool
lightCastsShadows (Types.Light properties) =
    properties.castsShadows


{-| -}
oneLight : Light coordinates a -> Lights coordinates
oneLight light =
    let
        lightMatrices =
            { lights12 = lightPair light Light.disabled
            , lights34 = lightPair Light.disabled Light.disabled
            , lights56 = lightPair Light.disabled Light.disabled
            , lights78 = lightPair Light.disabled Light.disabled
            }
    in
    if lightCastsShadows light then
        SingleShadowedPass lightMatrices

    else
        SingleUnshadowedPass lightMatrices


{-| -}
twoLights :
    Light coordinates a
    -> Light coordinates b
    -> Lights coordinates
twoLights first second =
    eightLights
        first
        second
        Light.disabled
        Light.disabled
        Light.disabled
        Light.disabled
        Light.disabled
        Light.disabled


{-| -}
threeLights :
    Light coordinates a
    -> Light coordinates b
    -> Light coordinates c
    -> Lights coordinates
threeLights first second third =
    eightLights
        first
        second
        third
        Light.disabled
        Light.disabled
        Light.disabled
        Light.disabled
        Light.disabled


{-| -}
fourLights :
    Light coordinates a
    -> Light coordinates b
    -> Light coordinates c
    -> Light coordinates d
    -> Lights coordinates
fourLights first second third fourth =
    eightLights
        first
        second
        third
        fourth
        Light.disabled
        Light.disabled
        Light.disabled
        Light.disabled


{-| -}
fiveLights :
    Light coordinates a
    -> Light coordinates b
    -> Light coordinates c
    -> Light coordinates d
    -> Light coordinates Never
    -> Lights coordinates
fiveLights first second third fourth fifth =
    eightLights
        first
        second
        third
        fourth
        fifth
        Light.disabled
        Light.disabled
        Light.disabled


{-| -}
sixLights :
    Light coordinates a
    -> Light coordinates b
    -> Light coordinates c
    -> Light coordinates d
    -> Light coordinates Never
    -> Light coordinates Never
    -> Lights coordinates
sixLights first second third fourth fifth sixth =
    eightLights
        first
        second
        third
        fourth
        fifth
        sixth
        Light.disabled
        Light.disabled


{-| -}
sevenLights :
    Light coordinates a
    -> Light coordinates b
    -> Light coordinates c
    -> Light coordinates d
    -> Light coordinates Never
    -> Light coordinates Never
    -> Light coordinates Never
    -> Lights coordinates
sevenLights first second third fourth fifth sixth seventh =
    eightLights
        first
        second
        third
        fourth
        fifth
        sixth
        seventh
        Light.disabled


eraseLight : Light coordinates castsShadows -> Light coordinates ()
eraseLight (Types.Light light) =
    Types.Light light


{-| -}
eightLights :
    Light coordinates a
    -> Light coordinates b
    -> Light coordinates c
    -> Light coordinates d
    -> Light coordinates Never
    -> Light coordinates Never
    -> Light coordinates Never
    -> Light coordinates Never
    -> Lights coordinates
eightLights first second third fourth fifth sixth seventh eigth =
    let
        ( enabledShadowCasters, disabledShadowCasters ) =
            List.partition lightCastsShadows
                [ eraseLight first
                , eraseLight second
                , eraseLight third
                , eraseLight fourth
                ]
    in
    case enabledShadowCasters of
        [] ->
            SingleUnshadowedPass
                { lights12 = lightPair first second
                , lights34 = lightPair third fourth
                , lights56 = lightPair fifth sixth
                , lights78 = lightPair seventh eigth
                }

        _ ->
            let
                sortedLights =
                    enabledShadowCasters ++ disabledShadowCasters
            in
            case sortedLights of
                [ light0, light1, light2, light3 ] ->
                    MultiplePasses (List.map singleLight enabledShadowCasters)
                        { lights12 = lightPair light0 light1
                        , lights34 = lightPair light2 light3
                        , lights56 = lightPair fifth sixth
                        , lights78 = lightPair seventh eigth
                        }

                _ ->
                    -- Can't happen
                    noLights



----- BACKGROUND -----


{-| Specifies the background used when rendering a scene. Currently only
constant background colors are supported, but eventually this will be expanded
to support more fancy things like skybox textures or backgrounds based on the
current environmental lighting.
-}
type Background coordinates
    = BackgroundColor Color.Transparent.Color


{-| A fully transparent background.
-}
transparentBackground : Background coordinates
transparentBackground =
    BackgroundColor <|
        Color.Transparent.fromRGBA
            { red = 0
            , green = 0
            , blue = 0
            , alpha = Color.Transparent.transparent
            }


{-| An opaque black background.
-}
blackBackground : Background coordinates
blackBackground =
    BackgroundColor <|
        Color.Transparent.fromRGBA
            { red = 0
            , green = 0
            , blue = 0
            , alpha = Color.Transparent.opaque
            }


{-| An opaque white background.
-}
whiteBackground : Background coordinates
whiteBackground =
    BackgroundColor <|
        Color.Transparent.fromRGBA
            { red = 255
            , green = 255
            , blue = 255
            , alpha = Color.Transparent.opaque
            }


{-| A custom opaque background color.
-}
backgroundColor : Color -> Background coordinates
backgroundColor color =
    BackgroundColor (Color.Transparent.fromColor Color.Transparent.opaque color)


{-| A custom background color with transparency.
-}
translucentBackground : Color.Transparent.Color -> Background coordinates
translucentBackground transparentColor =
    BackgroundColor transparentColor



----- RENDERING -----


type alias RenderPass lights =
    lights -> List WebGL.Settings.Setting -> WebGL.Entity


type alias RenderPasses =
    { meshes : List (RenderPass ( LightMatrices, Vec4 ))
    , shadows : List (RenderPass Mat4)
    , points : List (RenderPass ( LightMatrices, Vec4 ))
    }


createRenderPass : Mat4 -> Mat4 -> Mat4 -> Transformation -> DrawFunction lights -> RenderPass lights
createRenderPass sceneProperties viewMatrix projectionMatrix transformation drawFunction =
    let
        normalSign =
            if transformation.isRightHanded then
                1

            else
                -1

        modelScale =
            Math.Vector4.vec4
                transformation.scaleX
                transformation.scaleY
                transformation.scaleZ
                normalSign
    in
    drawFunction
        sceneProperties
        modelScale
        (Transformation.modelMatrix transformation)
        transformation.isRightHanded
        viewMatrix
        projectionMatrix


collectRenderPasses : Mat4 -> Mat4 -> Mat4 -> Transformation -> Node -> RenderPasses -> RenderPasses
collectRenderPasses sceneProperties viewMatrix projectionMatrix currentTransformation node accumulated =
    case node of
        EmptyNode ->
            accumulated

        Transformed transformation childNode ->
            collectRenderPasses
                sceneProperties
                viewMatrix
                projectionMatrix
                (Transformation.compose transformation currentTransformation)
                childNode
                accumulated

        MeshNode _ meshDrawFunction ->
            let
                updatedMeshes =
                    createRenderPass
                        sceneProperties
                        viewMatrix
                        projectionMatrix
                        currentTransformation
                        meshDrawFunction
                        :: accumulated.meshes
            in
            { meshes = updatedMeshes
            , shadows = accumulated.shadows
            , points = accumulated.points
            }

        PointNode _ pointDrawFunction ->
            let
                updatedPoints =
                    createRenderPass
                        sceneProperties
                        viewMatrix
                        projectionMatrix
                        currentTransformation
                        pointDrawFunction
                        :: accumulated.points
            in
            { meshes = accumulated.meshes
            , shadows = accumulated.shadows
            , points = updatedPoints
            }

        ShadowNode shadowDrawFunction ->
            let
                updatedShadows =
                    createRenderPass
                        sceneProperties
                        viewMatrix
                        projectionMatrix
                        currentTransformation
                        shadowDrawFunction
                        :: accumulated.shadows
            in
            { meshes = accumulated.meshes
            , shadows = updatedShadows
            , points = accumulated.points
            }

        Group childNodes ->
            List.foldl
                (collectRenderPasses
                    sceneProperties
                    viewMatrix
                    projectionMatrix
                    currentTransformation
                )
                accumulated
                childNodes


defaultBlend : WebGL.Settings.Setting
defaultBlend =
    Blend.custom
        { r = 0
        , g = 0
        , b = 0
        , a = 0
        , color = Blend.customAdd Blend.srcAlpha Blend.oneMinusSrcAlpha
        , alpha = Blend.customAdd Blend.one Blend.oneMinusSrcAlpha
        }


depthTestDefault : List WebGL.Settings.Setting
depthTestDefault =
    [ DepthTest.default, defaultBlend ]


outsideStencil : List WebGL.Settings.Setting
outsideStencil =
    [ DepthTest.lessOrEqual { write = True, near = 0, far = 1 }
    , StencilTest.test
        { ref = 0
        , mask = upperFourBits
        , test = StencilTest.equal
        , fail = StencilTest.keep
        , zfail = StencilTest.keep
        , zpass = StencilTest.keep
        , writeMask = 0
        }
    , defaultBlend
    ]


insideStencil : Int -> List WebGL.Settings.Setting
insideStencil lightMask =
    [ DepthTest.lessOrEqual { write = True, near = 0, far = 1 }
    , StencilTest.test
        { ref = lightMask
        , mask = upperFourBits
        , test = StencilTest.equal
        , fail = StencilTest.keep
        , zfail = StencilTest.keep
        , zpass = StencilTest.keep
        , writeMask = 0
        }
    , defaultBlend
    ]


createShadowStencil : List WebGL.Settings.Setting
createShadowStencil =
    -- Note that the actual stencil test is added by each individual shadow
    -- entity (in Scene3d.Entity.shadowSettings) since the exact test to perform
    -- depends on whether the current model matrix is right-handed or
    -- left-handed
    [ DepthTest.greaterOrEqual { write = False, near = 0, far = 1 }
    , WebGL.Settings.colorMask False False False False
    , WebGL.Settings.polygonOffset 0.0 1.0
    ]


call : List (RenderPass lights) -> lights -> List WebGL.Settings.Setting -> List WebGL.Entity
call renderPasses lights settings =
    List.map (\renderPass -> renderPass lights settings) renderPasses


updateViewBounds : Frame3d Meters modelCoordinates { defines : viewCoordinates } -> Float -> Float -> Float -> Bounds -> Maybe (BoundingBox3d Meters viewCoordinates) -> Maybe (BoundingBox3d Meters viewCoordinates)
updateViewBounds viewFrame scaleX scaleY scaleZ modelBounds current =
    let
        i =
            Direction3d.unwrap (Frame3d.xDirection viewFrame)

        j =
            Direction3d.unwrap (Frame3d.yDirection viewFrame)

        k =
            Direction3d.unwrap (Frame3d.zDirection viewFrame)

        modelXDimension =
            2 * modelBounds.halfX * scaleX

        modelYDimension =
            2 * modelBounds.halfY * scaleY

        modelZDimension =
            2 * modelBounds.halfZ * scaleZ

        xDimension =
            abs (modelXDimension * i.x) + abs (modelYDimension * i.y) + abs (modelZDimension * i.z)

        yDimension =
            abs (modelXDimension * j.x) + abs (modelYDimension * j.y) + abs (modelZDimension * j.z)

        zDimension =
            abs (modelXDimension * k.x) + abs (modelYDimension * k.y) + abs (modelZDimension * k.z)

        nodeBounds =
            BoundingBox3d.withDimensions
                ( Quantity xDimension, Quantity yDimension, Quantity zDimension )
                (Point3d.relativeTo viewFrame (Point3d.fromMeters modelBounds.centerPoint))
    in
    case current of
        Just currentBounds ->
            Just (BoundingBox3d.union currentBounds nodeBounds)

        Nothing ->
            Just nodeBounds


getViewBounds : Frame3d Meters modelCoordinates { defines : viewCoordinates } -> Float -> Float -> Float -> Maybe (BoundingBox3d Meters viewCoordinates) -> List Node -> Maybe (BoundingBox3d Meters viewCoordinates)
getViewBounds viewFrame scaleX scaleY scaleZ current nodes =
    case nodes of
        first :: rest ->
            case first of
                Types.EmptyNode ->
                    getViewBounds viewFrame scaleX scaleY scaleZ current rest

                Types.MeshNode modelBounds _ ->
                    let
                        updated =
                            updateViewBounds viewFrame scaleX scaleY scaleZ modelBounds current
                    in
                    getViewBounds viewFrame scaleX scaleY scaleZ updated rest

                Types.ShadowNode _ ->
                    getViewBounds viewFrame scaleX scaleY scaleZ current rest

                Types.PointNode modelBounds _ ->
                    let
                        updated =
                            updateViewBounds viewFrame scaleX scaleY scaleZ modelBounds current
                    in
                    getViewBounds viewFrame scaleX scaleY scaleZ updated rest

                Types.Group childNodes ->
                    getViewBounds
                        viewFrame
                        scaleX
                        scaleY
                        scaleZ
                        (getViewBounds viewFrame scaleX scaleY scaleZ current childNodes)
                        rest

                Types.Transformed transformation childNode ->
                    let
                        localScaleX =
                            scaleX * transformation.scaleX

                        localScaleY =
                            scaleY * transformation.scaleY

                        localScaleZ =
                            scaleZ * transformation.scaleZ

                        localViewFrame =
                            viewFrame
                                |> Frame3d.relativeTo (Transformation.placementFrame transformation)
                    in
                    getViewBounds
                        viewFrame
                        scaleX
                        scaleY
                        scaleZ
                        (getViewBounds
                            localViewFrame
                            localScaleX
                            localScaleY
                            localScaleZ
                            current
                            [ childNode ]
                        )
                        rest

        [] ->
            current


fullScreenQuadMesh : WebGL.Mesh { position : Vec2 }
fullScreenQuadMesh =
    WebGL.triangleStrip
        [ { position = Math.Vector2.vec2 -1 -1 }
        , { position = Math.Vector2.vec2 1 -1 }
        , { position = Math.Vector2.vec2 -1 1 }
        , { position = Math.Vector2.vec2 1 1 }
        ]


fullScreenQuadVertexShader : WebGL.Shader { position : Vec2 } {} {}
fullScreenQuadVertexShader =
    [glsl|
        precision lowp float;

        attribute vec2 position;

        void main() {
            gl_Position = vec4(position, 0.0, 1.0);
        }
    |]


dummyFragmentShader : WebGL.Shader {} {} {}
dummyFragmentShader =
    [glsl|
        precision lowp float;

        void main() {
            gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
        }
    |]


updateStencil :
    { ref : Int
    , mask : Int
    , test : StencilTest.Test
    , fail : StencilTest.Operation
    , zfail : StencilTest.Operation
    , zpass : StencilTest.Operation
    , writeMask : Int
    }
    -> WebGL.Entity
updateStencil test =
    WebGL.entityWith
        [ StencilTest.test test
        , WebGL.Settings.colorMask False False False False
        ]
        fullScreenQuadVertexShader
        dummyFragmentShader
        fullScreenQuadMesh
        {}


initStencil : WebGL.Entity
initStencil =
    updateStencil
        { ref = initialStencilCount
        , mask = 0
        , test = StencilTest.always
        , fail = StencilTest.replace
        , zfail = StencilTest.replace
        , zpass = StencilTest.replace
        , writeMask = 0xFF
        }


initialStencilCount : Int
initialStencilCount =
    8


lowerFourBits : Int
lowerFourBits =
    0x0F


upperFourBits : Int
upperFourBits =
    0xF0


resetStencil : WebGL.Entity
resetStencil =
    updateStencil
        { ref = initialStencilCount
        , mask = 0
        , test = StencilTest.always
        , fail = StencilTest.replace
        , zfail = StencilTest.replace
        , zpass = StencilTest.replace
        , writeMask = lowerFourBits
        }


singleLightMask : Int -> Int
singleLightMask index =
    2 ^ (index + 4)


storeStencilValue : Int -> WebGL.Entity
storeStencilValue lightIndex =
    updateStencil
        { ref = initialStencilCount
        , mask = lowerFourBits
        , test = StencilTest.greater
        , fail = StencilTest.keep
        , zfail = StencilTest.invert
        , zpass = StencilTest.invert
        , writeMask = singleLightMask lightIndex
        }


{-| This function lets you convert a list of `elm-3d-scene` entities into a list
of plain `elm-explorations/webgl` entities, so that you can combine objects
rendered with `elm-3d-scene` with custom objects you render yourself.

Note that the arguments are not exactly the same as `toHtml`; there are no
`background`, `dimensions` or `antialiasing` arguments since those are
properties that must be set at the top level, so you will have to handle those
yourself when calling [`WebGL.toHtml`](https://package.elm-lang.org/packages/elm-explorations/webgl/latest/WebGL#toHtml).
However, there are a couple of additional arguments:

  - You must specify the `aspectRatio` (width over height) that the scene is
    being rendered at, so that projection matrices can be computed correctly.
    (In `Scene3d.toHtml`, aspect ratio is computed from the given dimensions.)
  - You must specify the current supersampling factor being used, if any. This
    allows the circular dots used to render points to have the same radius
    whether or not supersampling is used (e.g. if using 2x supersampling, then
    points must be rendered at twice the pixel radius internally so that the
    final result has the same visual size). If you're not using supersampling,
    set this value to 1.

This function is called internally by `toHtml` but has not actually been tested
in combination with other custom WebGL code, so there is a high chance of weird
interaction bugs. (In particular, if you use the stencil buffer you will likely
want to clear it explicitly after rendering `elm-3d-scene` entities.) If you
encounter bugs when using `toWebGLEntities` in combination with your own custom
rendering code, please [open an issue](https://github.com/ianmackenzie/elm-3d-scene/issues/new)
or reach out to **@ianmackenzie** on the [Elm Slack](http://elmlang.herokuapp.com/).

-}
toWebGLEntities :
    { lights : Lights coordinates
    , camera : Camera3d Meters coordinates
    , clipDepth : Length
    , exposure : Exposure
    , toneMapping : ToneMapping
    , whiteBalance : Chromaticity
    , aspectRatio : Float
    , supersampling : Float
    , entities : List (Entity coordinates)
    }
    -> List WebGL.Entity
toWebGLEntities arguments =
    let
        viewpoint =
            Camera3d.viewpoint arguments.camera

        (Types.Entity rootNode) =
            Entity.group arguments.entities

        viewFrame =
            Frame3d.unsafe
                { originPoint = Viewpoint3d.eyePoint viewpoint
                , xDirection = Viewpoint3d.xDirection viewpoint
                , yDirection = Viewpoint3d.yDirection viewpoint
                , zDirection = Direction3d.reverse (Viewpoint3d.viewDirection viewpoint)
                }
    in
    case getViewBounds viewFrame 1 1 1 Nothing [ rootNode ] of
        Nothing ->
            -- Empty view bounds means there's nothing to render!
            []

        Just viewBounds ->
            let
                ( xDimension, yDimension, zDimension ) =
                    BoundingBox3d.dimensions viewBounds

                -- Used as the offset value when constructing shadows,
                -- to ensure they extend all the way out of the scene
                sceneDiameter =
                    Vector3d.length (Vector3d.xyz xDimension yDimension zDimension)

                nearClipDepth =
                    -- If nearest object is further away than the given
                    -- clip depth, then use that (larger) depth instead
                    -- to get better depth buffer accuracy for free
                    Quantity.max
                        (Quantity.abs arguments.clipDepth)
                        (Quantity.negate (BoundingBox3d.maxZ viewBounds))
                        -- Accommodate for a bit of roundoff error,
                        -- ensure things right at the near plane
                        -- don't get clipped
                        |> Quantity.multiplyBy 0.99

                farClipDepth =
                    -- Start at the maximum distance anything is from
                    -- the camera
                    Quantity.negate (BoundingBox3d.minZ viewBounds)
                        -- Ensure shadows don't get clipped (shadows
                        -- extend past actual scene geometry)
                        |> Quantity.plus sceneDiameter
                        -- Accommodate for a bit of roundoff error,
                        -- ensure things right at the far plane
                        -- don't get clipped
                        |> Quantity.multiplyBy 1.01

                projectionMatrix =
                    WebGL.projectionMatrix arguments.camera
                        { aspectRatio = arguments.aspectRatio
                        , nearClipDepth = nearClipDepth
                        , farClipDepth = farClipDepth
                        }

                projectionType =
                    (Math.Matrix4.toRecord projectionMatrix).m44

                eyePointOrDirectionToCamera =
                    if projectionType == 0 then
                        -- Perspective projection
                        Point3d.toMeters (Viewpoint3d.eyePoint viewpoint)

                    else
                        -- Orthographic projection
                        Viewpoint3d.viewDirection viewpoint
                            |> Direction3d.reverse
                            |> Direction3d.unwrap

                (Exposure exposureLuminance) =
                    arguments.exposure

                (LinearRgb referenceWhite) =
                    ColorConversions.chromaticityToLinearRgb exposureLuminance arguments.whiteBalance

                ( toneMapType, toneMapParam ) =
                    case arguments.toneMapping of
                        NoToneMapping ->
                            ( 0, 0 )

                        ReinhardLuminanceToneMapping ->
                            ( 1, 0 )

                        ReinhardPerChannelToneMapping ->
                            ( 2, 0 )

                        ExtendedReinhardLuminanceToneMapping overexposureLimit ->
                            ( 3, overexposureLimit )

                        ExtendedReinhardPerChannelToneMapping overexposureLimit ->
                            ( 4, overexposureLimit )

                        HableFilmicToneMapping ->
                            ( 5, 0 )

                -- ## Overall scene Properties
                --
                -- [ *  cameraX         whiteR  supersampling ]
                -- [ *  cameraY         whiteG  sceneDiameter ]
                -- [ *  cameraZ         whiteB  toneMapType   ]
                -- [ *  projectionType  *       toneMapParam  ]
                --
                sceneProperties =
                    Math.Matrix4.fromRecord
                        { m11 = 0
                        , m21 = 0
                        , m31 = 0
                        , m41 = 0
                        , m12 = eyePointOrDirectionToCamera.x
                        , m22 = eyePointOrDirectionToCamera.y
                        , m32 = eyePointOrDirectionToCamera.z
                        , m42 = projectionType
                        , m13 = Math.Vector3.getX referenceWhite
                        , m23 = Math.Vector3.getY referenceWhite
                        , m33 = Math.Vector3.getZ referenceWhite
                        , m43 = 0
                        , m14 = arguments.supersampling
                        , m24 = Length.inMeters sceneDiameter
                        , m34 = toneMapType
                        , m44 = toneMapParam
                        }

                viewMatrix =
                    WebGL.viewMatrix viewpoint

                renderPasses =
                    collectRenderPasses
                        sceneProperties
                        viewMatrix
                        projectionMatrix
                        Transformation.identity
                        rootNode
                        { meshes = []
                        , shadows = []
                        , points = []
                        }
            in
            case arguments.lights of
                SingleUnshadowedPass lightMatrices ->
                    List.concat
                        [ call renderPasses.meshes ( lightMatrices, allLightsEnabled ) depthTestDefault
                        , call renderPasses.points lightingDisabled depthTestDefault
                        ]

                SingleShadowedPass lightMatrices ->
                    List.concat
                        [ call renderPasses.meshes lightingDisabled depthTestDefault
                        , [ initStencil ]
                        , call renderPasses.shadows lightMatrices.lights12 createShadowStencil
                        , [ storeStencilValue 0 ]
                        , call renderPasses.meshes ( lightMatrices, allLightsEnabled ) outsideStencil
                        , call renderPasses.points lightingDisabled depthTestDefault
                        ]

                MultiplePasses shadowCasters allLightMatrices ->
                    List.concat
                        [ call renderPasses.meshes ( allLightMatrices, allLightsEnabled ) depthTestDefault
                        , [ initStencil ]
                        , createShadows renderPasses.shadows shadowCasters
                        , renderWithinShadows renderPasses.meshes allLightMatrices (List.length shadowCasters)
                        , call renderPasses.points lightingDisabled depthTestDefault
                        ]


createShadows : List (RenderPass Mat4) -> List Mat4 -> List WebGL.Entity
createShadows shadowRenderPasses shadowCasters =
    List.concat (List.indexedMap (createShadow shadowRenderPasses) shadowCasters)


createShadow : List (RenderPass Mat4) -> Int -> Mat4 -> List WebGL.Entity
createShadow shadowRenderPasses lightIndex lightMatrix =
    List.concat
        [ call shadowRenderPasses lightMatrix createShadowStencil
        , [ storeStencilValue lightIndex, resetStencil ]
        ]


enabledFlag : Int -> Int -> Float
enabledFlag lightMask lightIndex =
    if (lightMask |> Bitwise.shiftRightBy lightIndex |> Bitwise.and 1) == 1 then
        0

    else
        1


renderWithinShadows : List (RenderPass ( LightMatrices, Vec4 )) -> LightMatrices -> Int -> List WebGL.Entity
renderWithinShadows meshRenderPasses lightMatrices numShadowingLights =
    List.range 1 ((2 ^ numShadowingLights) - 1)
        |> List.map
            (\lightMask ->
                let
                    stencilMask =
                        lightMask |> Bitwise.shiftLeftBy 4

                    enabledLights =
                        Math.Vector4.vec4
                            (enabledFlag lightMask 0)
                            (enabledFlag lightMask 1)
                            (enabledFlag lightMask 2)
                            (enabledFlag lightMask 3)
                in
                call meshRenderPasses ( lightMatrices, enabledLights ) (insideStencil stencilMask)
            )
        |> List.concat


{-| Actually render a scene! You need to specify:

  - The lights used to render the scene.
  - The position and orientation of the camera.
  - A clip depth (anything closer to the camera than this value will be clipped
    and not shown).
  - The overall [`exposure`](#Exposure) level to use.
  - What kind of [tone mapping](#ToneMapping) to apply, if any.
  - The white balance to use: this the chromaticity that will show up as white in
    the final rendered scene. It should generally be the dominant light color
    in the scene. `Scene3d.daylight` is a good default value, but for indoors
    scenes `Scene3d.fluorescentLighting` or `Scene3d.incandescentLighting`
    may be more appropriate.
  - What kind of [antialiasing](#Antialiasing) to use, if any.
  - The overall dimensions in pixels of the scene.
  - What background color to use.
  - A list of entities to render!

This allows full customization of how the scene is rendered; there are also some
simpler rendering [presets](#presets) to let you get started quickly with (for
example) a basic ['sunny day'](#sunny) scene.

-}
toHtml :
    { lights : Lights coordinates
    , camera : Camera3d Meters coordinates
    , clipDepth : Length
    , exposure : Exposure
    , toneMapping : ToneMapping
    , whiteBalance : Chromaticity
    , antialiasing : Antialiasing
    , dimensions : ( Quantity Float Pixels, Quantity Float Pixels )
    , background : Background coordinates
    , entities : List (Entity coordinates)
    }
    -> Html msg
toHtml arguments =
    composite
        { camera = arguments.camera
        , clipDepth = arguments.clipDepth
        , antialiasing = arguments.antialiasing
        , dimensions = arguments.dimensions
        , background = arguments.background
        }
        [ { lights = arguments.lights
          , exposure = arguments.exposure
          , toneMapping = arguments.toneMapping
          , whiteBalance = arguments.whiteBalance
          , entities = arguments.entities
          }
        ]


{-| Render a 'composite' scene where different subsets of entities in the scene
can use different lighting. This can let you do things like:

  - Work around the eight-light limitation by breaking a scene up into multiple
    sub-scenes that use different sets of lights
  - Render very high dynamic range scenes such as an interior room with a window
    out to a bright sunny day, by rendering different parts of the scene with
    different exposure/tone mapping settings

-}
composite :
    { camera : Camera3d Meters coordinates
    , clipDepth : Length
    , antialiasing : Antialiasing
    , dimensions : ( Quantity Float Pixels, Quantity Float Pixels )
    , background : Background coordinates
    }
    ->
        List
            { lights : Lights coordinates
            , exposure : Exposure
            , toneMapping : ToneMapping
            , whiteBalance : Chromaticity
            , entities : List (Entity coordinates)
            }
    -> Html msg
composite arguments scenes =
    let
        ( width, height ) =
            arguments.dimensions

        widthInPixels =
            inPixels width

        heightInPixels =
            inPixels height

        (BackgroundColor givenBackgroundColor) =
            arguments.background

        backgroundColorString =
            Color.Transparent.toRGBAString givenBackgroundColor

        commonWebGLOptions =
            [ WebGL.depth 1
            , WebGL.stencil 0
            , WebGL.alpha True
            , WebGL.clearColor 0 0 0 0
            ]

        -- Use key value to force WebGL context to be recreated if multisample
        -- antialising is enabled/disabled
        ( webGLOptions, key, scalingFactor ) =
            case arguments.antialiasing of
                NoAntialiasing ->
                    ( commonWebGLOptions, "0", 1 )

                Multisampling ->
                    ( WebGL.antialias :: commonWebGLOptions, "1", 1 )

                Supersampling value ->
                    ( commonWebGLOptions, "0", value )

        widthCss =
            Html.Attributes.style "width" (String.fromFloat widthInPixels ++ "px")

        heightCss =
            Html.Attributes.style "height" (String.fromFloat heightInPixels ++ "px")

        aspectRatio =
            Quantity.ratio width height

        webGLEntities =
            scenes
                |> List.concatMap
                    (\scene ->
                        toWebGLEntities
                            { lights = scene.lights
                            , camera = arguments.camera
                            , clipDepth = arguments.clipDepth
                            , exposure = scene.exposure
                            , toneMapping = scene.toneMapping
                            , whiteBalance = scene.whiteBalance
                            , aspectRatio = aspectRatio
                            , supersampling = scalingFactor
                            , entities = scene.entities
                            }
                    )
    in
    Html.Keyed.node "div" [ Html.Attributes.style "padding" "0px", widthCss, heightCss ] <|
        [ ( key
          , WebGL.toHtmlWith webGLOptions
                [ Html.Attributes.width (round (widthInPixels * scalingFactor))
                , Html.Attributes.height (round (heightInPixels * scalingFactor))
                , widthCss
                , heightCss
                , Html.Attributes.style "display" "block"
                , Html.Attributes.style "background-color" backgroundColorString
                ]
                webGLEntities
          )
        ]



----- EXPOSURE -----


{-| Exposure controls the overall brightness of a scene; just like a physical
camera, adjusting exposure can lead to a scene being under-exposed (very dark
everywhere) or over-exposed (very bright, potentially with some pure-white areas
where the scene has been 'blown out').
-}
type Exposure
    = Exposure Luminance


{-| Set exposure based on an [exposure value](https://en.wikipedia.org/wiki/Exposure_value)
for an ISO speed of 100. Typical exposure values range from 5 for home interiors
to 15 for sunny outdoor scenes; you can find some reference values [here](https://en.wikipedia.org/wiki/Exposure_value#Tabulated_exposure_values).
-}
exposureValue : Float -> Exposure
exposureValue ev100 =
    -- from https://media.contentapi.ea.com/content/dam/eacom/frostbite/files/course-notes-moving-frostbite-to-pbr-v2.pdf
    Exposure (Luminance.nits (1.2 * 2 ^ ev100))


{-| Set exposure based on the luminance of the brightest white that can be
displayed without overexposure. Scene luminance covers a large range of values;
some sample values can be found [here](https://en.wikipedia.org/wiki/Orders_of_magnitude_%28luminance%29).
-}
maxLuminance : Luminance -> Exposure
maxLuminance givenMaxLuminance =
    Exposure (Quantity.abs givenMaxLuminance)


{-| Set exposure based on photographic parameters: F-stop, shutter speed and
ISO film speed.
-}
photographicExposure : { fStop : Float, shutterSpeed : Duration, isoSpeed : Float } -> Exposure
photographicExposure { fStop, shutterSpeed, isoSpeed } =
    let
        t =
            Duration.inSeconds shutterSpeed
    in
    -- from https://media.contentapi.ea.com/content/dam/eacom/frostbite/files/course-notes-moving-frostbite-to-pbr-v2.pdf
    exposureValue (logBase 2 ((100 * fStop ^ 2) / (t * isoSpeed)))



----- TONE MAPPING -----


{-| Tone mapping is, roughly speaking, a way to render scenes that contain both
very dark and very bright areas. It works by mapping a large range of brightness
(luminance) values into a more limited set of values that can actually be
displayed on a computer monitor.
-}
type ToneMapping
    = NoToneMapping
    | ReinhardLuminanceToneMapping
    | ReinhardPerChannelToneMapping
    | ExtendedReinhardLuminanceToneMapping Float
    | ExtendedReinhardPerChannelToneMapping Float
    | HableFilmicToneMapping


{-| No tone mapping at all! In this case, the brightness of every point in the
scene will simply be scaled by the overall scene [exposure](#Exposure) setting
and the resulting color will be displayed on the screen. For scenes with bright
reflective highlights or a mix of dark and bright portions, this means that
some parts of the scene may be underexposed (nearly black) or overexposed
(pure white).

That said, it's often best to start with `noToneMapping` for simplicity, and
only experiment with other tone mapping methods if you end up with very bright,
harsh highlights that need to be toned down.

-}
noToneMapping : ToneMapping
noToneMapping =
    NoToneMapping


{-| Apply [Reinhard](https://64.github.io/tonemapping/#reinhard) tone mapping
given the maximum allowed overexposure. This will apply a non-linear scaling to
scene luminance (brightness) values such that darker colors will not be affected
very much (meaning the brightness of the scene as a whole will not be changed
dramatically), but very bright colors will be toned down to avoid
'blowout'/overexposure.

The given parameter specifies how much 'extra range' the tone mapping gives you;
for example,

    Scene3d.reinhardToneMapping 5

will mean that parts of the scene can be 5x brighter than normal before becoming
'overexposed' and pure white. (You could also accomplish that by changing the
overall `exposure` parameter to `Scene3d.toHtml`, but then the entire scene
would appear much darker.)

-}
reinhardToneMapping : Float -> ToneMapping
reinhardToneMapping maxOverexposure =
    if isInfinite maxOverexposure then
        ReinhardLuminanceToneMapping

    else
        ExtendedReinhardLuminanceToneMapping maxOverexposure


{-| A variant of `reinhardToneMapping` which applies the scaling operation to
red, green and blue channels separately instead of scaling overall luminance.
This will tend to desaturate bright colors, but this can end up being looking
realistic since very bright colored lights do in fact appear fairly white to our
eyes.
-}
reinhardPerChannelToneMapping : Float -> ToneMapping
reinhardPerChannelToneMapping maxOverexposure =
    if isInfinite maxOverexposure then
        ReinhardPerChannelToneMapping

    else
        ExtendedReinhardPerChannelToneMapping maxOverexposure


{-| A popular 'filmic' tone mapping method developed by John Hable for Uncharted
2 and documented [here](http://filmicworlds.com/blog/filmic-tonemapping-operators/).
It attempts to approximately reproduce how real film reacts to light. The
results are fairly similar to `reinhardPerChannelToneMapping 5`, but will tend
to have deeper blacks for a slightly less washed-out look. This is a good
default choice for realistic-looking scenes.
-}
hableFilmicToneMapping : ToneMapping
hableFilmicToneMapping =
    HableFilmicToneMapping



----- ANTIALIASING -----


{-| An `Antialiasing` value defines what (if any) kind of [antialiasing](https://en.wikipedia.org/wiki/Spatial_anti-aliasing)
is used when rendering a scene. Different types of antialiasing have different
tradeoffs between quality and rendering speed.
-}
type Antialiasing
    = NoAntialiasing
    | Multisampling
    | Supersampling Float


{-| No antialiasing at all. This is the fastest to render, but often results in
very visible jagged/pixelated edges.
-}
noAntialiasing : Antialiasing
noAntialiasing =
    NoAntialiasing


{-| [Multisample](https://en.wikipedia.org/wiki/Multisample_anti-aliasing)
antialiasing. This is generally a decent tradeoff between performance and
image quality. Using multisampling means that _edges_ of objects will generally
be smooth, but jaggedness _inside_ objects resulting from lighting or texturing
may still occur.
-}
multisampling : Antialiasing
multisampling =
    Multisampling


{-| Supersampling refers to a brute-force version of antialiasing: render the
entire scene at a higher resolution, then scale down. For example, using
`Scene3d.supersampling 2` will render at 2x dimensions in both X and Y (so
four times the total number of pixels) and then scale back down to the given
dimensions; this means that every pixel in the final result will be the average
of a 2x2 block of rendered pixels.

This is generally the highest-quality antialiasing but also the highest cost.
For simple cases supersampling is often indistinguishable from multisampling,
but supersampling is also capable of handling cases like small bright lighting
highlights that multisampling does not address.

-}
supersampling : Float -> Antialiasing
supersampling factor =
    Supersampling factor



----- PRESETS -----


{-| Render a simple scene without any lighting. This means all objects in the
scene should use [plain colors](Material#color) - without any lighting, other
material types will always be completely black!
-}
unlit :
    { dimensions : ( Quantity Float Pixels, Quantity Float Pixels )
    , camera : Camera3d Meters coordinates
    , clipDepth : Length
    , background : Background coordinates
    , entities : List (Entity coordinates)
    }
    -> Html msg
unlit arguments =
    toHtml
        { lights = noLights
        , camera = arguments.camera
        , clipDepth = arguments.clipDepth
        , exposure = maxLuminance (Luminance.nits 80) -- sRGB standard monitor brightness
        , whiteBalance = Light.daylight
        , antialiasing = multisampling
        , dimensions = arguments.dimensions
        , background = arguments.background
        , toneMapping = noToneMapping
        , entities = arguments.entities
        }


{-| Render an outdoors 'sunny day' scene given the overall global up direction
(usually `Direction3d.z` or `Direction3d.y` depending on how you've set up your
scene), the direction of incoming sunlight (e.g. `Direction3d.negativeZ` if
positive Z is up and the sun is directly overhead) and whether or not sunlight
should cast shadows.
-}
sunny :
    { upDirection : Direction3d coordinates
    , sunlightDirection : Direction3d coordinates
    , shadows : Bool
    , dimensions : ( Quantity Float Pixels, Quantity Float Pixels )
    , camera : Camera3d Meters coordinates
    , clipDepth : Length
    , background : Background coordinates
    , entities : List (Entity coordinates)
    }
    -> Html msg
sunny arguments =
    let
        sun =
            Light.directional (Light.castsShadows arguments.shadows)
                { direction = arguments.sunlightDirection
                , intensity = Illuminance.lux 80000
                , chromaticity = Light.sunlight
                }

        sky =
            Light.overhead
                { upDirection = arguments.upDirection
                , chromaticity = Light.skylight
                , intensity = Illuminance.lux 20000
                }

        environment =
            Light.overhead
                { upDirection = Direction3d.reverse arguments.upDirection
                , chromaticity = Light.daylight
                , intensity = Illuminance.lux 15000
                }

        lights =
            threeLights sun sky environment
    in
    toHtml
        { lights = lights
        , camera = arguments.camera
        , clipDepth = arguments.clipDepth
        , exposure = exposureValue 15
        , toneMapping = noToneMapping
        , whiteBalance = Light.daylight
        , antialiasing = multisampling
        , dimensions = arguments.dimensions
        , background = arguments.background
        , entities = arguments.entities
        }


{-| Render an outdoors 'cloudy day' scene. You must still provide a global up
direction since even on a cloudy day more light comes from above than
around/below a given object, but no direct sunlight means no shadows.
-}
cloudy :
    { dimensions : ( Quantity Float Pixels, Quantity Float Pixels )
    , upDirection : Direction3d coordinates
    , camera : Camera3d Meters coordinates
    , clipDepth : Length
    , background : Background coordinates
    , entities : List (Entity coordinates)
    }
    -> Html msg
cloudy arguments =
    toHtml
        { lights =
            oneLight <|
                Light.soft
                    { upDirection = arguments.upDirection
                    , chromaticity = Light.daylight
                    , intensityAbove = Illuminance.lux 1000
                    , intensityBelow = Illuminance.lux 200
                    }
        , camera = arguments.camera
        , clipDepth = arguments.clipDepth
        , exposure = exposureValue 13
        , toneMapping = noToneMapping
        , whiteBalance = Light.daylight
        , antialiasing = multisampling
        , dimensions = arguments.dimensions
        , background = arguments.background
        , entities = arguments.entities
        }


{-| Render an indoors office scene. Like `Scene3d.cloudy`, you will still need
to specify a global up direction.
-}
office :
    { upDirection : Direction3d coordinates
    , dimensions : ( Quantity Float Pixels, Quantity Float Pixels )
    , camera : Camera3d Meters coordinates
    , clipDepth : Length
    , background : Background coordinates
    , entities : List (Entity coordinates)
    }
    -> Html msg
office arguments =
    toHtml
        { lights =
            oneLight <|
                Light.soft
                    { upDirection = arguments.upDirection
                    , chromaticity = Light.fluorescent
                    , intensityAbove = Illuminance.lux 400
                    , intensityBelow = Illuminance.lux 100
                    }
        , camera = arguments.camera
        , clipDepth = arguments.clipDepth
        , exposure = exposureValue 7
        , toneMapping = noToneMapping
        , whiteBalance = Light.fluorescent
        , antialiasing = multisampling
        , dimensions = arguments.dimensions
        , background = arguments.background
        , entities = arguments.entities
        }
