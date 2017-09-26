# SwiftGlobe

An interactive 3D globe for iOS, tvOS, and MacOS X.  Built in Swift 3.1 using SceneKit.


![Screenshot on MacOS X](macos_screen.png)![Screenshot on iOS](ios_screen.png)![Screenshot on tvOS](tv_screen.png)

## Features

- Targets for macOS, iOS, & tvOS
- Visual quality
	- mountains cast shadows (implemented with a normal map)
	- water is reflecty, land is matte (implemented with metalness & roughness maps)
	- detailed milkyway in the background
	- use high-quality earth texture on macOS (looks great on retina displays, even when zoomed in)
- Accurate modeling
	- earth's axis varies by the current day of the year (north pole gets more sun in the summer, less in the winter)
	- tilt the milkyway relative to the solar system's orbital plane
- Interactive
	- support pan & zoom gestures
	- support tvOS remote, too (pan & zoom)
	- smooth camera movement (uses SceneKit physics with a camera gimbal)
	- glowing dots for markers 

## TODOs

In no particular order:
- [ ] add point-to-point connection visualization
- [ ] cubemap for earth texture (fix slight smearing at poles)
- [ ] fix normal map 'dimple' at the north pole
- [ ] show city lights on darkside (customized shader?)
- [ ] add an orbiting moon
- [ ] support scrollwheel zoom on Mac

### Requirements

Requires iOS 10 & macOS 10.12 Sierra. (SceneKit supports older targets, but some textures & physics would have to be removed).


## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* WWDC 2013 session 'What's new in SceneKit' (session, video, & demo source all very helpful)
* WWDC 2016 session 'Advances in SceneKit Rendering' (especially physically based materials)
* InfiniteRed's [interactive seven-foot globe](http://infinitered.com/2015/02/10/a-seven-foot-globe-running-on-os-x-and-an-ipad-app-created-using-rubymotion-and-scenekit/) (built with SceneKit & physics) 
* Milkyway Skymap
    * source image from European Southern Observatory (https://www.eso.org/public/usa/images/eso0932a/)
    * converted to cubemap (from equirectangular panorama) with a python script provided by Benjamin Dobell (http://stackoverflow.com/a/36976448/235229)
* Earth texture by Jim Hastings-Trew at http://planetpixelemporium.com/earth.html



