module Scene3d exposing
    ( toHtml
    , Option
    , multisampling, supersampling, dynamicRange
    , Entity
    , quad, block, sphere, cylinder
    , mesh
    , group, nothing
    , shadow, withShadow
    , rotateAround, translateBy, translateIn, scaleAbout, mirrorAcross
    , placeIn, relativeTo
    , transparentBackground, whiteBackground, blackBackground, backgroundColor, transparentBackgroundColor
    , defaultExposure, defaultWhiteBalance
    , Light, directionalLight, pointLight
    , CastsShadows, Yes, No, castsShadows, doesNotCastShadows
    , Lights, noLights, oneLight, twoLights, threeLights, fourLights, fiveLights, sixLights, sevenLights, eightLights
    , EnvironmentalLighting, noEnvironmentalLighting, softLighting
    , toWebGLEntities
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


# Options

@docs Option

@docs multisampling, supersampling, dynamicRange


# Entities

@docs Entity


## Basic shapes

`elm-3d-scene` includes a handful of basic shapes which you can draw directly
without having to create and store a separate [`Mesh`](Scene3d-Mesh). In
general, for all of the basic shapes you can specify whether or not it should
cast a shadow (assuming there is shadow-casting light in the scene!) and can
specify a material to use. However, different shapes support different kinds of
materials; `quad`s and `sphere`s support all materials, while `block`s and
`cylinder`s only support uniform (non-textured) materials.

@docs quad, block, sphere, cylinder


## Meshes

@docs mesh


## Grouping and toggling

@docs group, nothing


# Shadows

@docs shadow, withShadow


# Transformations

These transformations are 'cheap' in that they don't actually transform the
underlying mesh; under the hood they use a WebGL [transformation matrix](https://learnopengl.com/Getting-started/Transformations)
to change where that mesh gets rendered.

@docs rotateAround, translateBy, translateIn, scaleAbout, mirrorAcross


# Coordinate conversions

You're unlikely to need these functions right away but they can be very useful
when setting up more complex scenes.

@docs placeIn, relativeTo


# Background

@docs transparentBackground, whiteBackground, blackBackground, backgroundColor, transparentBackgroundColor


# Default rendering values

@docs defaultExposure, defaultWhiteBalance


# Lighting

Lighting in `elm-3d-scene` is a combination of _direct_ and _environmental_
(indirect, ambient) lighting. Direct lighting comes from specific lights like
the sun or a light bulb; you can currently have up to eight separate lights
in a scene. Environmental lighting accounts for light coming from all around an
object; for example, if you are outside, you might be getting direct light from
the sun but you're also getting light reflected from other surfaces around you.

Generally, direct lighting gives nice highlights but can be very harsh; it's
usually best to use a combination of some soft indirect lighting to ensure the
scene as a whole is reasonably well lit, and then use one or more point or
directional lights to provide highlights.


## Lights

@docs Light, directionalLight, pointLight

@docs CastsShadows, Yes, No, castsShadows, doesNotCastShadows

@docs Lights, noLights, oneLight, twoLights, threeLights, fourLights, fiveLights, sixLights, sevenLights, eightLights


## Environmental lighting

@docs EnvironmentalLighting, noEnvironmentalLighting, softLighting


# Advanced

@docs toWebGLEntities

-}

import Angle exposing (Angle)
import Axis3d exposing (Axis3d)
import Block3d exposing (Block3d)
import Camera3d exposing (Camera3d)
import Color exposing (Color)
import Color.Transparent
import Cylinder3d exposing (Cylinder3d)
import Direction3d exposing (Direction3d)
import Frame3d exposing (Frame3d)
import Geometry.Interop.LinearAlgebra.Frame3d as Frame3d
import Geometry.Interop.LinearAlgebra.Point3d as Point3d
import Html exposing (Html)
import Html.Attributes
import Html.Keyed
import Illuminance exposing (Illuminance)
import Length exposing (Length, Meters)
import Luminance exposing (Luminance)
import LuminousFlux exposing (LuminousFlux)
import Math.Matrix4 exposing (Mat4)
import Math.Vector3 exposing (Vec3)
import Math.Vector4 exposing (Vec4)
import Pixels exposing (Pixels, inPixels)
import Plane3d exposing (Plane3d)
import Point3d exposing (Point3d)
import Quantity exposing (Quantity(..))
import Rectangle2d
import Scene3d.Chromaticity as Chromaticity exposing (Chromaticity)
import Scene3d.ColorConversions as ColorConversions
import Scene3d.Entity as Entity
import Scene3d.Exposure as Exposure exposing (Exposure)
import Scene3d.Material as Material exposing (Material)
import Scene3d.Mesh as Mesh exposing (Mesh)
import Scene3d.Transformation as Transformation exposing (Transformation)
import Scene3d.Types as Types exposing (Bounds, DrawFunction, LightMatrices, LinearRgb(..), Material(..), Node(..))
import Sphere3d exposing (Sphere3d)
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
type alias Entity units coordinates =
    Types.Entity units coordinates


{-| A dummy entity for which nothing will be drawn.
-}
nothing : Entity units coordinates
nothing =
    Entity.empty


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
    CastsShadows a
    -> Material.Textured units coordinates
    -> Point3d units coordinates
    -> Point3d units coordinates
    -> Point3d units coordinates
    -> Point3d units coordinates
    -> Entity units coordinates
quad (CastsShadows shadowFlag) givenMaterial p1 p2 p3 p4 =
    Entity.quad shadowFlag givenMaterial p1 p2 p3 p4


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
sphere : CastsShadows a -> Material.Textured units coordinates -> Sphere3d units coordinates -> Entity units coordinates
sphere (CastsShadows shadowFlag) givenMaterial givenSphere =
    Entity.sphere shadowFlag givenMaterial givenSphere


{-| Draw a rectangular block using the [`Block3d`](https://package.elm-lang.org/packages/ianmackenzie/elm-geometry/latest/Block3d)
type from `elm-geometry`.
-}
block : CastsShadows a -> Material.Uniform units coordinates -> Block3d units coordinates -> Entity units coordinates
block (CastsShadows shadowFlag) givenMaterial givenBlock =
    Entity.block shadowFlag givenMaterial givenBlock


{-| Draw a cylinder using the [`Cylinder3d`](https://package.elm-lang.org/packages/ianmackenzie/elm-geometry/latest/Cylinder3d)
type from `elm-geometry`.
-}
cylinder : CastsShadows a -> Material.Uniform units coordinates -> Cylinder3d units coordinates -> Entity units coordinates
cylinder (CastsShadows shadowFlag) givenMaterial givenCylinder =
    Entity.cylinder shadowFlag givenMaterial givenCylinder


{-| Draw the given mesh (shape) with the given material. Check out the [`Mesh`](Scene3d-Mesh)
and [`Material`](Scene3d-Material) modules for how to define meshes and
materials. Note that the mesh and material types must line up, and this is
checked by the compiler; for example, a textured material that requires UV
coordinates can only be used on a mesh that includes UV coordinates!

If you want to also draw the shadow of a given object, you'll need to use
[`shadow`](#shadow) or [`withShadow`](#withShadow).

-}
mesh : Material units coordinates attributes -> Mesh units coordinates attributes -> Entity units coordinates
mesh givenMaterial givenMesh =
    Entity.mesh givenMaterial givenMesh


{-| Group a list of entities into a single entity. This combined entity can then
be transformed, grouped with other entities, etc.
-}
group : List (Entity units coordinates) -> Entity units coordinates
group entities =
    Entity.group entities


{-| Draw the _shadow_ of an object. Note that this means you can choose to
render an object and its shadow, and object without its shadow, or even render
an object's shadow without the object itself for [maximum creepiness](https://en.wikipedia.org/wiki/Identity_Crisis_(Star_Trek:_The_Next_Generation)).
-}
shadow : Mesh.Shadow units coordinates -> Entity units coordinates
shadow givenShadow =
    Entity.shadow givenShadow


{-| Convenience function for rendering an object and its shadow;

    Scene3d.withShadow shadow entity

is shorthand for

    Scene3d.group [ entity, Scene3d.shadow shadow ]

-}
withShadow : Mesh.Shadow units coordinates -> Entity units coordinates -> Entity units coordinates
withShadow givenShadow givenEntity =
    group [ givenEntity, shadow givenShadow ]


{-| Rotate an entity around a given axis by a given angle.
-}
rotateAround : Axis3d units coordinates -> Angle -> Entity units coordinates -> Entity units coordinates
rotateAround axis angle entity =
    Entity.rotateAround axis angle entity


{-| Translate (move) an entity by a given displacement vector.
-}
translateBy : Vector3d units coordinates -> Entity units coordinates -> Entity units coordinates
translateBy displacement entity =
    Entity.translateBy displacement entity


{-| Translate an entity in a given direction by a given distance.
-}
translateIn : Direction3d coordinates -> Quantity Float units -> Entity units coordinates -> Entity units coordinates
translateIn direction distance entity =
    Entity.translateIn direction distance entity


{-| Scale an entity about a given point by a given scale. The given point will
remain fixed in place and all other points on the entity will be stretched away
from that point (or contract towards that point, if the scale is less than one).

`elm-3d-scene` tries very hard to do the right thing here even if you use a
_negative_ scale factor, but that flips the mesh inside out so I don't really
recommend it.

-}
scaleAbout : Point3d units coordinates -> Float -> Entity units coordinates -> Entity units coordinates
scaleAbout centerPoint scale entity =
    Entity.scaleAbout centerPoint scale entity


{-| Mirror an entity across a plane.
-}
mirrorAcross : Plane3d units coordinates -> Entity units coordinates -> Entity units coordinates
mirrorAcross plane entity =
    Entity.mirrorAcross plane entity


{-| Take an entity that is defined in a local coordinate system and convert it
to global coordinates. This can be useful if you have some entities which are
defined in some local coordinate system like inside a car, and you want to
render them within a larger world.
-}
placeIn : Frame3d units coordinates { defines : localCoordinates } -> Entity units localCoordinates -> Entity units coordinates
placeIn frame entity =
    Entity.placeIn frame entity


{-| Take an entity that is defined in global coordinates and convert into a
local coordinate system. This is even less likely to be useful than `placeIn`,
but may be useful if you are (for example) rendering an office scene (and
working primarily in local room coordinates) but want to incorporate some entity
defined in global coordinates like a bird flying past the window.
-}
relativeTo : Frame3d units coordinates { defines : localCoordinates } -> Entity units coordinates -> Entity units localCoordinates
relativeTo frame entity =
    Entity.relativeTo frame entity



----- LIGHT SOURCES -----
--
-- type:
--   0 : disabled
--   1 : directional (XYZ is direction to light, i.e. reversed light direction)
--   2 : point (XYZ is light position)
--
-- radius is unused for now (will hopefully add sphere lights in the future)
--
-- [ x_i     r_i       x_j     r_j      ]
-- [ y_i     g_i       y_j     g_j      ]
-- [ z_i     b_i       z_j     b_j      ]
-- [ type_i  radius_i  type_j  radius_j ]


{-| A `Light` represents a single source of light in the scene, such as the sun
or a light bulb. Lights are not rendered themselves; they can only be seen by
how they interact with objects in the scene.
-}
type alias Light units coordinates castsShadows =
    Types.Light units coordinates castsShadows


{-| A `Lights` value represents the set of all lights in a scene. There are a
couple of current limitations to note in `elm-3d-scene`:

  - No more than eight lights can exist in the scene
  - Only _one_ of those lights can cast shadows

(The reason there is a separate `Lights` type, instead of just using a list of
`Light` values, is so that the type system can be used to guarantee these
constraints are satisfied.)

-}
type Lights units coordinates
    = SingleUnshadowedPass LightMatrices
    | SingleShadowedPass LightMatrices
    | TwoPasses LightMatrices LightMatrices


disabledLight : Light units coordinates castsShadows
disabledLight =
    Types.Light
        { type_ = 0
        , castsShadows = False
        , x = 0
        , y = 0
        , z = 0
        , r = 0
        , g = 0
        , b = 0
        , radius = 0
        }


lightPair : Light units coordinates firstCastsShadows -> Light units coordinates secondCastsShadows -> Mat4
lightPair (Types.Light first) (Types.Light second) =
    Math.Matrix4.fromRecord
        { m11 = first.x
        , m21 = first.y
        , m31 = first.z
        , m41 = first.type_
        , m12 = first.r
        , m22 = first.g
        , m32 = first.b
        , m42 = first.radius
        , m13 = second.x
        , m23 = second.y
        , m33 = second.z
        , m43 = second.type_
        , m14 = second.r
        , m24 = second.g
        , m34 = second.b
        , m44 = second.radius
        }


lightingDisabled : LightMatrices
lightingDisabled =
    { lights12 = lightPair disabledLight disabledLight
    , lights34 = lightPair disabledLight disabledLight
    , lights56 = lightPair disabledLight disabledLight
    , lights78 = lightPair disabledLight disabledLight
    }


{-| No lights at all! You don't need lights if you're only using materials
like [`color`](Material#color) or [`emissive`](Material#emissive) (since those
materials don't react to light anyways).
-}
noLights : Lights units coordinates
noLights =
    SingleUnshadowedPass lightingDisabled


lightCastsShadows : Light units coordinates castsShadows -> Bool
lightCastsShadows (Types.Light properties) =
    properties.castsShadows


oneLight : Light units coordinates (CastsShadows a) -> Lights units coordinates
oneLight light =
    let
        lightMatrices =
            { lights12 = lightPair light disabledLight
            , lights34 = lightPair disabledLight disabledLight
            , lights56 = lightPair disabledLight disabledLight
            , lights78 = lightPair disabledLight disabledLight
            }
    in
    if lightCastsShadows light then
        SingleShadowedPass lightMatrices

    else
        SingleUnshadowedPass lightMatrices


twoLights :
    Light units coordinates (CastsShadows a)
    -> Light units coordinates (CastsShadows No)
    -> Lights units coordinates
twoLights first second =
    eightLights
        first
        second
        disabledLight
        disabledLight
        disabledLight
        disabledLight
        disabledLight
        disabledLight


threeLights :
    Light units coordinates (CastsShadows a)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Lights units coordinates
threeLights first second third =
    eightLights
        first
        second
        third
        disabledLight
        disabledLight
        disabledLight
        disabledLight
        disabledLight


fourLights :
    Light units coordinates (CastsShadows a)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Lights units coordinates
fourLights first second third fourth =
    eightLights
        first
        second
        third
        fourth
        disabledLight
        disabledLight
        disabledLight
        disabledLight


fiveLights :
    Light units coordinates (CastsShadows a)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Lights units coordinates
fiveLights first second third fourth fifth =
    eightLights
        first
        second
        third
        fourth
        fifth
        disabledLight
        disabledLight
        disabledLight


sixLights :
    Light units coordinates (CastsShadows a)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Lights units coordinates
sixLights first second third fourth fifth sixth =
    eightLights
        first
        second
        third
        fourth
        fifth
        sixth
        disabledLight
        disabledLight


sevenLights :
    Light units coordinates (CastsShadows a)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Lights units coordinates
sevenLights first second third fourth fifth sixth seventh =
    eightLights
        first
        second
        third
        fourth
        fifth
        sixth
        seventh
        disabledLight


eightLights :
    Light units coordinates (CastsShadows a)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Light units coordinates (CastsShadows No)
    -> Lights units coordinates
eightLights first second third fourth fifth sixth seventh eigth =
    if lightCastsShadows first then
        TwoPasses
            { lights12 = lightPair first second
            , lights34 = lightPair third fourth
            , lights56 = lightPair fifth sixth
            , lights78 = lightPair seventh eigth
            }
            { lights12 = lightPair second third
            , lights34 = lightPair fourth fifth
            , lights56 = lightPair sixth seventh
            , lights78 = lightPair eigth disabledLight
            }

    else
        SingleUnshadowedPass
            { lights12 = lightPair first second
            , lights34 = lightPair third fourth
            , lights56 = lightPair fifth sixth
            , lights78 = lightPair seventh eigth
            }


type CastsShadows a
    = CastsShadows Bool


type Yes
    = Yes


type No
    = No


castsShadows : CastsShadows Yes
castsShadows =
    CastsShadows True


doesNotCastShadows : CastsShadows No
doesNotCastShadows =
    CastsShadows False


directionalLight :
    CastsShadows a
    ->
        { chromaticity : Chromaticity
        , intensity : Illuminance
        , direction : Direction3d coordinates
        }
    -> Light Meters coordinates (CastsShadows a)
directionalLight (CastsShadows shadowFlag) { chromaticity, intensity, direction } =
    let
        { x, y, z } =
            Direction3d.unwrap direction

        (LinearRgb rgb) =
            ColorConversions.chromaticityToLinearRgb chromaticity

        lux =
            Illuminance.inLux intensity
    in
    Types.Light
        { type_ = 1
        , castsShadows = shadowFlag
        , x = -x
        , y = -y
        , z = -z
        , r = lux * Math.Vector3.getX rgb
        , g = lux * Math.Vector3.getY rgb
        , b = lux * Math.Vector3.getZ rgb
        , radius = 0
        }


pointLight :
    CastsShadows a
    ->
        { chromaticity : Chromaticity
        , intensity : LuminousFlux
        , position : Point3d Meters coordinates
        }
    -> Light Meters coordinates (CastsShadows a)
pointLight (CastsShadows shadowFlag) { chromaticity, intensity, position } =
    let
        (LinearRgb rgb) =
            ColorConversions.chromaticityToLinearRgb chromaticity

        lumens =
            LuminousFlux.inLumens intensity

        { x, y, z } =
            Point3d.unwrap position
    in
    Types.Light
        { type_ = 2
        , castsShadows = shadowFlag
        , x = x
        , y = y
        , z = z
        , r = lumens * Math.Vector3.getX rgb
        , g = lumens * Math.Vector3.getY rgb
        , b = lumens * Math.Vector3.getZ rgb
        , radius = 0
        }



----- ENVIRONMENTAL LIGHTING ------


type alias EnvironmentalLighting units coordinates =
    Types.EnvironmentalLighting units coordinates


environmentalLightingDisabled : Mat4
environmentalLightingDisabled =
    Math.Matrix4.fromRecord
        { m11 = 0
        , m21 = 0
        , m31 = 0
        , m41 = 0
        , m12 = 0
        , m22 = 0
        , m32 = 0
        , m42 = 0
        , m13 = 0
        , m23 = 0
        , m33 = 0
        , m43 = 0
        , m14 = 0
        , m24 = 0
        , m34 = 0
        , m44 = 0
        }


noEnvironmentalLighting : EnvironmentalLighting units coordinates
noEnvironmentalLighting =
    Types.NoEnvironmentalLighting


{-| Good default value for max luminance: 5000 nits
-}
softLighting :
    { upDirection : Direction3d coordinates
    , above : ( Luminance, Chromaticity )
    , below : ( Luminance, Chromaticity )
    }
    -> EnvironmentalLighting Meters coordinates
softLighting { upDirection, above, below } =
    let
        { x, y, z } =
            Direction3d.unwrap upDirection

        ( aboveLuminance, aboveChromaticity ) =
            above

        ( belowLuminance, belowChromaticity ) =
            below

        aboveNits =
            Luminance.inNits aboveLuminance

        belowNits =
            Luminance.inNits belowLuminance

        (LinearRgb aboveRgb) =
            ColorConversions.chromaticityToLinearRgb aboveChromaticity

        (LinearRgb belowRgb) =
            ColorConversions.chromaticityToLinearRgb belowChromaticity
    in
    Types.SoftLighting <|
        Math.Matrix4.fromRecord
            { m11 = x
            , m21 = y
            , m31 = z
            , m41 = 1
            , m12 = aboveNits * Math.Vector3.getX aboveRgb
            , m22 = aboveNits * Math.Vector3.getY aboveRgb
            , m32 = aboveNits * Math.Vector3.getZ aboveRgb
            , m42 = 0
            , m13 = belowNits * Math.Vector3.getX belowRgb
            , m23 = belowNits * Math.Vector3.getY belowRgb
            , m33 = belowNits * Math.Vector3.getZ belowRgb
            , m43 = 0
            , m14 = 0
            , m24 = 0
            , m34 = 0
            , m44 = 0
            }



----- BACKGROUND -----


type Background units coordinates
    = BackgroundColor Color.Transparent.Color


transparentBackground : Background units coordinates
transparentBackground =
    BackgroundColor <|
        Color.Transparent.fromRGBA
            { red = 0
            , green = 0
            , blue = 0
            , alpha = Color.Transparent.transparent
            }


blackBackground : Background units coordinates
blackBackground =
    BackgroundColor <|
        Color.Transparent.fromRGBA
            { red = 0
            , green = 0
            , blue = 0
            , alpha = Color.Transparent.opaque
            }


whiteBackground : Background units coordinates
whiteBackground =
    BackgroundColor <|
        Color.Transparent.fromRGBA
            { red = 255
            , green = 255
            , blue = 255
            , alpha = Color.Transparent.opaque
            }


backgroundColor : Color -> Background units coordinates
backgroundColor color =
    BackgroundColor (Color.Transparent.fromColor Color.Transparent.opaque color)


transparentBackgroundColor : Color.Transparent.Color -> Background units coordinates
transparentBackgroundColor transparentColor =
    BackgroundColor transparentColor



----- DEFAULTS -----


defaultExposure : Exposure
defaultExposure =
    Exposure.srgb


defaultWhiteBalance : Chromaticity
defaultWhiteBalance =
    Chromaticity.d65



----- RENDERING -----


type alias RenderPass =
    LightMatrices -> List WebGL.Settings.Setting -> WebGL.Entity


type alias RenderPasses =
    { meshes : List RenderPass
    , shadows : List RenderPass
    , points : List RenderPass
    }


createRenderPass : Mat4 -> Mat4 -> Mat4 -> Mat4 -> Transformation -> DrawFunction -> RenderPass
createRenderPass sceneProperties viewMatrix projectionMatrix ambientLightingMatrix transformation drawFunction =
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
        ambientLightingMatrix


collectRenderPasses : Mat4 -> Mat4 -> Mat4 -> Mat4 -> Transformation -> Node -> RenderPasses -> RenderPasses
collectRenderPasses sceneProperties viewMatrix projectionMatrix ambientLightingMatrix currentTransformation node accumulated =
    case node of
        EmptyNode ->
            accumulated

        Transformed transformation childNode ->
            collectRenderPasses
                sceneProperties
                viewMatrix
                projectionMatrix
                ambientLightingMatrix
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
                        ambientLightingMatrix
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
                        ambientLightingMatrix
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
                        ambientLightingMatrix
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
                    ambientLightingMatrix
                    currentTransformation
                )
                accumulated
                childNodes



-- ## Overall scene Properties
--
-- projectionType:
--   0: perspective (camera XYZ is eye position)
--   1: orthographic (camera XYZ is direction to screen)
--
-- [ clipDistance  cameraX         whiteR        supersampling ]
-- [ aspectRatio   cameraY         whiteG        *             ]
-- [ kc            cameraZ         whiteB        *             ]
-- [ kz            projectionType  dynamicRange  *             ]


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
        , mask = 0xFF
        , test = StencilTest.equal
        , fail = StencilTest.keep
        , zfail = StencilTest.keep
        , zpass = StencilTest.keep
        , writeMask = 0x00
        }
    , defaultBlend
    ]


insideStencil : List WebGL.Settings.Setting
insideStencil =
    [ DepthTest.lessOrEqual { write = True, near = 0, far = 1 }
    , StencilTest.test
        { ref = 0
        , mask = 0xFF
        , test = StencilTest.notEqual
        , fail = StencilTest.keep
        , zfail = StencilTest.keep
        , zpass = StencilTest.keep
        , writeMask = 0x00
        }
    , defaultBlend
    ]


createShadowStencil : List WebGL.Settings.Setting
createShadowStencil =
    -- Note that the actual stencil test is added by each individual shadow
    -- entity (in Scene3d.Entity.shadowSettings) since the exact test to perform
    -- depends on whether the current model matrix is right-handed or
    -- left-handed
    [ DepthTest.less { write = False, near = 0, far = 1 }
    , WebGL.Settings.colorMask False False False False
    ]


call : List RenderPass -> LightMatrices -> List WebGL.Settings.Setting -> List WebGL.Entity
call renderPasses lightMatrices settings =
    renderPasses
        |> List.map (\renderPass -> renderPass lightMatrices settings)


getMaxDepth : Bounds -> Axis3d Meters coordinates -> Float -> Float -> Float -> Length
getMaxDepth bounds viewAxis scaleX scaleY scaleZ =
    let
        centerPoint =
            Point3d.fromMeters bounds.centerPoint

        viewDir =
            Direction3d.unwrap (Axis3d.direction viewAxis)

        (Quantity d0) =
            Point3d.signedDistanceAlong viewAxis centerPoint

        dX =
            abs (bounds.halfX * viewDir.x * scaleX)

        dY =
            abs (bounds.halfY * viewDir.y * scaleY)

        dZ =
            abs (bounds.halfZ * viewDir.z * scaleZ)
    in
    Quantity (d0 + dX + dY + dZ)


getFarClipDepth : Axis3d Meters coordinates -> Length -> Float -> Float -> Float -> List Node -> Length
getFarClipDepth viewAxis currentValue scaleX scaleY scaleZ nodes =
    case nodes of
        first :: rest ->
            case first of
                Types.EmptyNode ->
                    getFarClipDepth viewAxis currentValue scaleX scaleY scaleZ rest

                Types.MeshNode bounds _ ->
                    let
                        updatedValue =
                            Quantity.max currentValue
                                (getMaxDepth bounds viewAxis scaleX scaleY scaleZ)
                    in
                    getFarClipDepth viewAxis updatedValue scaleX scaleY scaleZ rest

                Types.ShadowNode _ ->
                    getFarClipDepth viewAxis currentValue scaleX scaleY scaleZ rest

                Types.PointNode bounds _ ->
                    let
                        updatedValue =
                            Quantity.max currentValue
                                (getMaxDepth bounds viewAxis scaleX scaleY scaleZ)
                    in
                    getFarClipDepth viewAxis updatedValue scaleX scaleY scaleZ rest

                Types.Group childNodes ->
                    getFarClipDepth
                        viewAxis
                        (getFarClipDepth viewAxis currentValue scaleX scaleY scaleZ childNodes)
                        scaleX
                        scaleY
                        scaleZ
                        rest

                Types.Transformed transformation childNode ->
                    let
                        localScaleX =
                            scaleX * transformation.scaleX

                        localScaleY =
                            scaleY * transformation.scaleY

                        localScaleZ =
                            scaleZ * transformation.scaleZ

                        localViewAxis =
                            viewAxis
                                |> Axis3d.relativeTo (Transformation.placementFrame transformation)
                    in
                    getFarClipDepth
                        viewAxis
                        (getFarClipDepth
                            localViewAxis
                            currentValue
                            localScaleX
                            localScaleY
                            localScaleZ
                            [ childNode ]
                        )
                        scaleX
                        scaleY
                        scaleZ
                        rest

        [] ->
            currentValue


toWebGLEntities :
    { lights : Lights units coordinates
    , environmentalLighting : EnvironmentalLighting units coordinates
    , camera : Camera3d units coordinates
    , clipDepth : Quantity Float units
    , exposure : Exposure units
    , dynamicRange : Float
    , whiteBalance : Chromaticity
    , aspectRatio : Float
    , supersampling : Float
    }
    -> List (Entity units coordinates)
    -> List WebGL.Entity
toWebGLEntities arguments drawables =
    let
        viewpoint =
            Camera3d.viewpoint arguments.camera

        (Types.Entity rootNode) =
            Entity.group drawables

        viewAxis =
            Axis3d.through (Viewpoint3d.eyePoint viewpoint) (Viewpoint3d.viewDirection viewpoint)

        farClipDepth =
            getFarClipDepth viewAxis arguments.clipDepth 1 1 1 [ rootNode ]

        projectionMatrix =
            WebGL.projectionMatrix arguments.camera
                { aspectRatio = arguments.aspectRatio
                , nearClipDepth = arguments.clipDepth
                , farClipDepth =
                    if farClipDepth == arguments.clipDepth then
                        Quantity.positiveInfinity

                    else
                        farClipDepth
                }

        projectionType =
            (Math.Matrix4.toRecord projectionMatrix).m44

        eyePointOrDirectionToCamera =
            if projectionType == 0 then
                Point3d.toMeters (Viewpoint3d.eyePoint viewpoint)

            else
                Viewpoint3d.viewDirection viewpoint
                    |> Direction3d.reverse
                    |> Direction3d.unwrap

        (LinearRgb linearRgb) =
            ColorConversions.chromaticityToLinearRgb arguments.whiteBalance

        maxLuminance =
            Luminance.inNits (Exposure.maxLuminance arguments.exposure)

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
                , m13 = maxLuminance * Math.Vector3.getX linearRgb
                , m23 = maxLuminance * Math.Vector3.getY linearRgb
                , m33 = maxLuminance * Math.Vector3.getZ linearRgb
                , m43 = arguments.dynamicRange
                , m14 = arguments.supersampling
                , m24 = 0
                , m34 = 0
                , m44 = 0
                }

        viewMatrix =
            WebGL.viewMatrix viewpoint

        environmentalLightingMatrix =
            case arguments.environmentalLighting of
                Types.SoftLighting matrix ->
                    matrix

                Types.NoEnvironmentalLighting ->
                    environmentalLightingDisabled

        renderPasses =
            collectRenderPasses
                sceneProperties
                viewMatrix
                projectionMatrix
                environmentalLightingMatrix
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
                [ call renderPasses.meshes lightMatrices depthTestDefault
                , call renderPasses.points lightingDisabled depthTestDefault
                ]

        SingleShadowedPass lightMatrices ->
            List.concat
                [ call renderPasses.meshes lightingDisabled depthTestDefault
                , call renderPasses.shadows lightMatrices createShadowStencil
                , call renderPasses.meshes lightMatrices outsideStencil
                , call renderPasses.points lightingDisabled depthTestDefault
                ]

        TwoPasses allLightMatrices unshadowedLightMatrices ->
            List.concat
                [ call renderPasses.meshes allLightMatrices depthTestDefault
                , call renderPasses.shadows allLightMatrices createShadowStencil
                , call renderPasses.meshes unshadowedLightMatrices insideStencil
                , call renderPasses.points lightingDisabled depthTestDefault
                ]


toHtml :
    List Option
    ->
        { lights : Lights units coordinates
        , environmentalLighting : EnvironmentalLighting coordinates
        , camera : Camera3d Meters coordinates
        , clipDepth : Length
        , exposure : Exposure
        , whiteBalance : Chromaticity
        , dimensions : ( Quantity Float Pixels, Quantity Float Pixels )
        , background : Background
        }
    -> List (Entity units coordinates)
    -> Html msg
toHtml options arguments drawables =
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

        optionValues =
            collectOptionValues options

        commonWebGLOptions =
            [ WebGL.depth 1
            , WebGL.stencil 0
            , WebGL.alpha True
            , WebGL.clearColor 0 0 0 0
            ]

        webGLOptions =
            if optionValues.multisampling then
                WebGL.antialias :: commonWebGLOptions

            else
                commonWebGLOptions

        -- Force WebGL context to be recreated if multisampling option changes
        key =
            if optionValues.multisampling then
                "1"

            else
                "0"

        widthCss =
            Html.Attributes.style "width" (String.fromFloat widthInPixels ++ "px")

        heightCss =
            Html.Attributes.style "height" (String.fromFloat heightInPixels ++ "px")
    in
    Html.Keyed.node "div" [ Html.Attributes.style "padding" "0px", widthCss, heightCss ] <|
        [ ( key
          , WebGL.toHtmlWith webGLOptions
                [ Html.Attributes.width (round (widthInPixels * optionValues.supersampling))
                , Html.Attributes.height (round (heightInPixels * optionValues.supersampling))
                , widthCss
                , heightCss
                , Html.Attributes.style "display" "block"
                , Html.Attributes.style "background-color" backgroundColorString
                ]
                (toWebGLEntities
                    { lights = arguments.lights
                    , environmentalLighting = arguments.environmentalLighting
                    , camera = arguments.camera
                    , clipDepth = arguments.clipDepth
                    , exposure = arguments.exposure
                    , dynamicRange = optionValues.dynamicRange
                    , whiteBalance = arguments.whiteBalance
                    , aspectRatio = Quantity.ratio width height
                    , supersampling = optionValues.supersampling
                    }
                    drawables
                )
          )
        ]


type Option
    = Multisampling Bool
    | Supersampling Float
    | DynamicRange Float


multisampling : Bool -> Option
multisampling =
    Multisampling


supersampling : Float -> Option
supersampling =
    Supersampling


dynamicRange : Float -> Option
dynamicRange =
    DynamicRange


type alias OptionValues =
    { multisampling : Bool
    , supersampling : Float
    , dynamicRange : Float
    }


defaultOptionValues : OptionValues
defaultOptionValues =
    { multisampling = True
    , supersampling = 1
    , dynamicRange = 1
    }


collectOptionValues : List Option -> OptionValues
collectOptionValues options =
    List.foldl setOption defaultOptionValues options


setOption : Option -> OptionValues -> OptionValues
setOption option currentValues =
    case option of
        Multisampling value ->
            { currentValues | multisampling = value }

        Supersampling value ->
            { currentValues | supersampling = value }

        DynamicRange value ->
            { currentValues | dynamicRange = value }
