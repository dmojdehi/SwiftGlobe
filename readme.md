# SwiftGlobe

An interactive 3D globe for iOS and MacOS X, built in Swift & SceneKit.

## TODOs

This project is just getting started.

- [x] MacOS X & iOS
- [x] Pan Left & Right
- [x] pinch to zoom
- [x] limit pan speed for smooth scrolling
- [x] show shadows in mountainous areas (normal map)
- [x] water is reflecty, land is matte (metalness & roughness maps)
- [x] tilt axis 23.5 degrees relative to the sun
- [x] bonus: vary tilt by the current season
- [x] use physics tricks for smooth camera movement
- [x] place glowing dots for markers
- [x] milkyway skybox background
- [ ] add tvOS target, too
- [ ] support scrollwheel zoom on Mac
- [ ] higher quality milkyway (cubemap)
- [ ] higher quality earth texture (for high-end displays)
- [ ] tilt milkyway correctly (relative to solar system's orbital plane)
- [ ] cubemap for earth texture (not smeared at poles)
- [ ] show city lights on darkside (customized shader?)
- [ ] moon


![Screenshot on MacOS X](macos_screen.png)![Screenshot on iOS](ios_screen.png)


### Prerequisites

Requires iOS 10 & macOS 10.12 Sierra. (Older versions of both could be supported by )  


## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* WWDC 2013 session 'What's new in SceneKit' (session, video, & demo source all very helpful)
* WWDC 2016 session 'Advances in SceneKit Rendering' (especially physically based materials)
* InfiniteRed's [interactive seven-foot globe](http://infinitered.com/2015/02/10/a-seven-foot-globe-running-on-os-x-and-an-ipad-app-created-using-rubymotion-and-scenekit/) (built with SceneKit & physics) 

