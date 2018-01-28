//
//  IJSVGRadialGradient.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGRadialGradient.h"

@implementation IJSVGRadialGradient

@synthesize cx;
@synthesize cy;
@synthesize fx;
@synthesize fy;
@synthesize radius;

- (void)dealloc
{
    [cx release], cx = nil;
    [cy release], cy = nil;
    [fx release], fx = nil;
    [fy release], fy = nil;
    [radius release], radius = nil;
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    IJSVGRadialGradient * grad = [super copyWithZone:zone];
    grad.fx = self.fx;
    grad.fy = self.fy;
    grad.cx = self.cx;
    grad.cy = self.cy;
    grad.radius = self.radius;
    return grad;
}


+ (NSGradient *)parseGradient:(NSXMLElement *)element
                     gradient:(IJSVGRadialGradient *)gradient
{
    // cx defaults to 50% if not specified
    NSDictionary * kv = @{@"cx":@"cx",
                          @"cy":@"cy",
                          @"r":@"radius"};
    
    for(NSString * key in kv.allKeys) {
        NSString * str = [element attributeForName:key].stringValue;
        IJSVGUnitLength * unit = nil;
        if(str != nil) {
            unit = [IJSVGUnitLength unitWithString:str];
        } else {
            unit = [IJSVGUnitLength unitWithPercentageFloat:.5f];
        }
        [gradient setValue:unit
                    forKey:kv[key]];
    }
    
    // needs fixing
    gradient.fx = gradient.cx;
    gradient.fy = gradient.cy;
  
    if( gradient.gradient != nil ) {
        return nil;
    }
    
    NSArray * colors = nil;
    CGFloat * colorStops = [[self class] computeColorStopsFromString:element colors:&colors];
    NSGradient * ret = [[[NSGradient alloc] initWithColors:colors
                                               atLocations:colorStops
                                                colorSpace:[NSColorSpace genericRGBColorSpace]] autorelease];
    free(colorStops);
    return ret;
}

- (void)drawInContextRef:(CGContextRef)ctx
              objectRect:(NSRect)objectRect
       absoluteTransform:(CGAffineTransform)absoluteTransform
                viewPort:(CGRect)viewBox
{
    BOOL inUserSpace = self.units == IJSVGUnitUserSpaceOnUse;
    CGFloat radius = self.radius.value;
    CGPoint startPoint = CGPointZero;
    CGPoint gradientStartPoint = CGPointZero;
    CGPoint gradientEndPoint = CGPointZero;
    
    // transforms
    CGAffineTransform absTransform = absoluteTransform;
    CGAffineTransform selfTransform = IJSVGConcatTransforms(self.transforms);
    
    CGContextSaveGState(ctx);
    {
#pragma mark User Space On Use
        if(inUserSpace == YES) {
            CGFloat rad = radius*2.f;
            startPoint = CGPointMake(self.cx.value, self.cy.value);
            
            // work out the new radius
            CGRect rect = CGRectMake(startPoint.x, startPoint.y, rad, rad);
            rect = CGRectApplyAffineTransform(rect, selfTransform);
            rect = CGRectApplyAffineTransform(rect, absTransform);
            radius = CGRectGetHeight(rect)/2.f;
            
            gradientStartPoint = startPoint;
            gradientEndPoint = CGPointMake(self.fx.value, self.fy.value);
                        
            // apply the absolute position
            CGContextConcatCTM(ctx, absTransform);
        } else {
#pragma mark Object Bounding Box
            // compute size based on percentages
            CGFloat x = [self.cx computeValue:CGRectGetWidth(objectRect)];
            CGFloat y = [self.cy computeValue:CGRectGetHeight(objectRect)];
            startPoint = CGPointMake(x, y);
            CGFloat val = MIN(CGRectGetWidth(objectRect), CGRectGetHeight(objectRect));
            radius = [self.radius computeValue:val];
            
            CGFloat ex = [self.fx computeValue:CGRectGetWidth(objectRect)];
            CGFloat ey = [self.fy computeValue:CGRectGetHeight(objectRect)];
            
            gradientEndPoint = CGPointMake(ex, ey);
            gradientStartPoint = startPoint;
            
            // transform if width or height is not equal
            if(CGRectGetWidth(objectRect) != CGRectGetHeight(objectRect)) {
                CGAffineTransform tr = CGAffineTransformMakeTranslation(gradientStartPoint.x,
                                                                        gradientStartPoint.y);
                if(CGRectGetWidth(objectRect) > CGRectGetHeight(objectRect)) {
                    tr = CGAffineTransformScale(tr, CGRectGetWidth(objectRect)/CGRectGetHeight(objectRect), 1);
                } else {
                    tr = CGAffineTransformScale(tr, 1.f, CGRectGetHeight(objectRect)/CGRectGetWidth(objectRect));
                }
                tr = CGAffineTransformTranslate(tr, -gradientStartPoint.x, -gradientStartPoint.y);
                selfTransform = CGAffineTransformConcat(tr, selfTransform);
            }
        }

#pragma mark Default drawing
        // transform the context
        CGContextConcatCTM(ctx, selfTransform);
    
        // draw the gradient
        CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation|
            kCGGradientDrawsAfterEndLocation;
        CGContextDrawRadialGradient(ctx, self.CGGradient,
                                    gradientStartPoint, 0, gradientEndPoint,
                                    radius, options);
    };
    CGContextRestoreGState(ctx);
}

@end
