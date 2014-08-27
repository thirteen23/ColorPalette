#ColorPalette

###Example project utilizing the T23Kit-Colour cocoapod
-------------
**H**, **S**, & **V** obviously controls the **H** ue, **S** aturation, & **V** alue.

**L**, **A**, **B** & **∆** sliders control the distance vector for each dimension in the CEILAB colourspace

![Alt text](https://github.com/thirteen23/ColorPalette/blob/master/screen_shot.jpg)

##Overview of Algorithm
-------------
The heuristic for palette generation is a bit crude but when dealing with colour palette generation there isn't ever an exact science. It starts by understanding that the [CIELAB](http://en.wikipedia.org/wiki/Lab_color_space) colourspace is a human percepted colorspace with 3 dimensions. It just so happens that these three dimensions form an [ellipsoid](http://en.wikipedia.org/wiki/Ellipsoid) that's shaped like a somewhat deflated soccer ball.

The algorithm works by taking a seed colour translating it into CIELAB colourspace and then bounds it by a randomly derived (from the delta values above) mini ellipsoid. It then generates random points within that ellipsoid until it acquires a valid neighbour colour.

The guts of this can be seen in the file [ColorPaletteGenerator.m](https://github.com/thirteen23/ColorPalette/blob/master/ColorPalette/ColorPaletteGenerator.m):


    CGFloat lambda_neg = (0 == arc4random() % 2) ? 1.0f : -1.0f;
    CGFloat beta_neg = (0 == arc4random() % 2) ? 1.0f : -1.0f;
    
    CGFloat lambda = ((CGFloat)arc4random() / (CGFloat)RAND_MAX) * M_PI * lambda_neg;
    CGFloat beta = ((CGFloat)arc4random() / (CGFloat)RAND_MAX) * M_PI_2 * beta_neg;
    
    x = aX * cos(beta) * cos(lambda);
    y = aY * cos(beta) * sin(lambda);
    z = bZ * sin(beta);
    
Obviously one could derive colours that sit outside the spectrum of sRGB which is why this method is implemented asynchronously as it needs to loop and filter results till it can sieve out matches for the **∆** value.

##Releases
-------------
Releases are tagged in the git commit history using (mostly) [semantic versioning](http://semver.org). Check out the [releases and release notes](https://github.com/thirteen23/T23Kit-Colour/blob/master/RELEASE) for each version.

Designed & maintained by [Thirteen23 Developers](mailto:dev@thirteen23.com). Distributed with the MIT license.
