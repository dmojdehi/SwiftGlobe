# SwiftGlobe

An interactive 3D globe for iOS, tvOS, and MacOS X.  Built in Swift 3.1 using SceneKit.


![Screenshot on MacOS X](macos_screen.png)![Screenshot on iOS](ios_screen.png)![Screenshot on tvOS](tv_screen.png)


## TODOs


- [x] targets for macOS, iOS, & tvOS
- accurate modeling
	- [x] bonus: vary tilt by the current day of the year
	- [x] earth axis is tilted correctly (23.5 degrees relative to the sun)
	- [x] tilt milkyway correctly (relative to solar system's orbital plane)
	- [ ] moon
- visual quality
	- [x] show shadows in mountainous areas (normal map)
	- [x] water is reflecty, land is matte (metalness & roughness maps)
	- [x] milkyway background
	- [x] higher quality earth texture on macOS (for high-end displays)
	- [ ] cubemap for earth texture (not smeared at poles)
	- [ ] show city lights on darkside (customized shader?)

- interactivity
	- [x] support pan & zoom gestures
	- [x] support tvOS remote, too (pan & zoom)
	- [x] smooth camera movement (uses physics tricks)
	- [x] glowing dots for markers
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
