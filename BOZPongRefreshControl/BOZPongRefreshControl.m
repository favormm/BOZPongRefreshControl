//
//  BOZPongRefreshControl.m
//  Ben Oztalay
//
//  Created by Ben Oztalay on 11/22/13.
//  Copyright (c) 2013 Ben Oztalay. All rights reserved.
//

#import "BOZPongRefreshControl.h"

#define REFRESH_CONTROL_HEIGHT 65.0f
#define HALF_REFRESH_CONTROL_HEIGHT (REFRESH_CONTROL_HEIGHT / 2.0f)

#define GAME_COLOR [UIColor whiteColor]

#define BALL_END_TO_END_DURATION 1.0f

#define PI 3.14159265359

typedef enum {
    BOZPongRefreshControlStateIdle = 0,
    BOZPongRefreshControlStateRefreshing = 1,
    BOZPongRefreshControlStateResetting = 2
} BOZPongRefreshControlState;

@interface BOZPongRefreshControl() {
    BOZPongRefreshControlState state;
    
    CGFloat originalTopContentInset;
    
    UIView* leftPaddleView;
    UIView* rightPaddleView;
    UIView* ballView;
    UILabel* releaseToRefreshLabel;
    
    CGPoint leftPaddleIdleOrigin;
    CGPoint rightPaddleIdleOrigin;
    CGPoint ballIdleOrigin;
    
    CGPoint ballOrigin;
    CGPoint ballDestination;
    CGPoint ballDirection;
    
    CGFloat leftPaddleDestination;
    CGFloat rightPaddleDestination;
}

@end

@implementation BOZPongRefreshControl

#pragma mark - Init

+ (BOZPongRefreshControl*)attachToTableView:(UITableView*)tableView withTarget:(UIViewController*)target andAction:(SEL)refreshAction
{
    if(tableView.tableHeaderView != nil && [tableView.tableHeaderView isKindOfClass:[BOZPongRefreshControl class]]) {
        return (BOZPongRefreshControl*)tableView.tableHeaderView;
    }
    
    BOZPongRefreshControl* pongRefreshControl = [[BOZPongRefreshControl alloc] initWithFrame:CGRectMake(0.0f, 0.0f, tableView.frame.size.width, REFRESH_CONTROL_HEIGHT)
                                                                                andTableView:tableView
                                                                                   andTarget:target
                                                                            andRefreshAction:refreshAction];
    [tableView setTableHeaderView:pongRefreshControl];
    
    return pongRefreshControl;
}

- (id)initWithFrame:(CGRect)frame
       andTableView:(UITableView*)tableView
          andTarget:(UIViewController*)target
   andRefreshAction:(SEL)refreshAction
{
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = YES;
        
        self.tableView = tableView;
        self.target = target;
        self.refreshAction = refreshAction;
        
        state = BOZPongRefreshControlStateIdle;
        
        originalTopContentInset = self.tableView.contentInset.top;
        UIEdgeInsets currentInsets = self.tableView.contentInset;
        currentInsets.top = originalTopContentInset - REFRESH_CONTROL_HEIGHT;
        self.tableView.contentInset = currentInsets;
        
        leftPaddleIdleOrigin = CGPointMake(self.frame.size.width * 0.25f, self.frame.size.height);
        leftPaddleView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 2.0f, 15.0f)];
        leftPaddleView.center = leftPaddleIdleOrigin;
        leftPaddleView.backgroundColor = GAME_COLOR;
        
        rightPaddleIdleOrigin = CGPointMake(self.frame.size.width * 0.75f, self.frame.size.height);
        rightPaddleView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 2.0f, 15.0f)];
        rightPaddleView.center = rightPaddleIdleOrigin;
        rightPaddleView.backgroundColor = GAME_COLOR;
        
        ballIdleOrigin = CGPointMake(self.frame.size.width * 0.50f, 0.0f);
        ballView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 3.0f, 3.0f)];
        ballView.center = ballIdleOrigin;
        ballView.backgroundColor = GAME_COLOR;
        
        [self addSubview:leftPaddleView];
        [self addSubview:rightPaddleView];
        [self addSubview:ballView];
        
        self.backgroundColor = [UIColor colorWithWhite:0.10f alpha:1.0f];
    }
    return self;
}

- (BOOL)isiOS7OrAbove
{
    return ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0f);
}

#pragma mark - Resetting after loading finished

- (void)finishedLoading
{
    if(state != BOZPongRefreshControlStateRefreshing) {
        return;
    }
    
    state = BOZPongRefreshControlStateResetting;
    
    [UIView animateWithDuration:0.2f animations:^(void)
    {
        UIEdgeInsets newInsets = self.tableView.contentInset;
        newInsets.top = originalTopContentInset - REFRESH_CONTROL_HEIGHT;
        self.tableView.contentInset = newInsets;
    }
    completion:^(BOOL finished)
    {
        [leftPaddleView.layer removeAllAnimations];
        [rightPaddleView.layer removeAllAnimations];
        [ballView.layer removeAllAnimations];
        
        leftPaddleView.center = leftPaddleIdleOrigin;
        rightPaddleView.center = rightPaddleIdleOrigin;
        ballView.center = ballIdleOrigin;
        
        state = BOZPongRefreshControlStateIdle;
    }];
}

#pragma mark - Listening to scrolling

- (void)tableViewScrolled
{
    if(state == BOZPongRefreshControlStateIdle) {
        //Moving and rotating the paddles and ball into place
        
        CGFloat rawOffset = REFRESH_CONTROL_HEIGHT - self.tableView.contentOffset.y - originalTopContentInset;
        CGFloat offset = MIN(rawOffset / 2.0f, HALF_REFRESH_CONTROL_HEIGHT);
        
        NSLog(@"contentOffset: %f; rawOffset: %f; offset: %f", self.tableView.contentOffset.y, rawOffset, offset);
        
        ballView.center = CGPointMake(ballIdleOrigin.x, ballIdleOrigin.y + offset);
        leftPaddleView.center = CGPointMake(leftPaddleIdleOrigin.x, leftPaddleIdleOrigin.y - offset);
        rightPaddleView.center = CGPointMake(rightPaddleIdleOrigin.x, rightPaddleIdleOrigin.y - offset);
        
        CGFloat proportionToMaxOffset = (offset / HALF_REFRESH_CONTROL_HEIGHT);
        CGFloat angleToRotate = PI * proportionToMaxOffset;
        
        leftPaddleView.transform = CGAffineTransformMakeRotation(angleToRotate);
        rightPaddleView.transform = CGAffineTransformMakeRotation(-angleToRotate);
        
        releaseToRefreshLabel.alpha = proportionToMaxOffset;
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
- (void)userStoppedDragging
{
    if(state == BOZPongRefreshControlStateIdle) {
        if(self.tableView.contentOffset.y < -originalTopContentInset) {
            state = BOZPongRefreshControlStateRefreshing;
        
            //Animate back into place
            [UIView animateWithDuration:0.2f animations:^(void) {
                UIEdgeInsets newInsets = self.tableView.contentInset;
                newInsets.top = originalTopContentInset;
                self.tableView.contentInset = newInsets;
            }];
            
            //Start the game
            ballOrigin = ballView.center;
            [self pickRandomBallDestination];
            [self determineNextPaddleDestinations];
            [self animateBallAndPaddles];
            
            //Let the target know
            [self.target performSelector:self.refreshAction];
        }
    }
}
#pragma clang diagnostic pop

#pragma mark - Controlling the ball

- (void)animateBallAndPaddles
{
    CGFloat endToEndDistance = [self rightPaddleContactX] - [self leftPaddleContactX];
    CGFloat horizontalProportionLeft = fabsf((ballDestination.x - ballView.center.x) / endToEndDistance);
    CGFloat animationDuration = BALL_END_TO_END_DURATION * horizontalProportionLeft;
    
    [UIView animateWithDuration:animationDuration delay:0.0f options:UIViewAnimationOptionCurveLinear animations:^(void)
    {
        ballView.center = ballDestination;
        leftPaddleView.center = CGPointMake(leftPaddleView.center.x, leftPaddleDestination);
        rightPaddleView.center = CGPointMake(rightPaddleView.center.x, rightPaddleDestination);
    }
    completion:^(BOOL finished)
    {
        if(finished) {
            [self determineNextBallDestination];
            [self determineNextPaddleDestinations];
            [self animateBallAndPaddles];
        }
    }];
}

//Yeah, sorry... I'll clean this up in a bit.
- (void)determineNextBallDestination
{
    CGFloat newBallDestinationX;
    CGFloat newBallDestinationY;
    
    CGPoint reflectedBallDirection;
    
    if([self didBallHitWall]) {
        reflectedBallDirection = CGPointMake(ballDirection.x, -ballDirection.y);
    } else if([self didBallHitPaddle]) {
        reflectedBallDirection = CGPointMake(-ballDirection.x, ballDirection.y);
    }
    
    CGFloat distanceToNextWall;
    CGFloat verticalDistanceToNextWall;
    
    if(reflectedBallDirection.y > 0.0f) {
        verticalDistanceToNextWall = [self floorContactY] - ballDestination.y;
    } else {
        verticalDistanceToNextWall = [self ceilingContactY] - ballDestination.y;
    }
    distanceToNextWall = verticalDistanceToNextWall / reflectedBallDirection.y;
    
    CGFloat horizontalDistanceToNextWall = distanceToNextWall * reflectedBallDirection.x;
    CGFloat horizontalDistanceToNextPaddle;
    
    if(reflectedBallDirection.x < 0.0f) {
        horizontalDistanceToNextPaddle = [self leftPaddleContactX] - ballDestination.x;
    } else {
        horizontalDistanceToNextPaddle = [self rightPaddleContactX] - ballDestination.x;
    }
    
    if(fabsf(horizontalDistanceToNextPaddle) < fabsf(horizontalDistanceToNextWall)) {
        newBallDestinationX = ballDestination.x + horizontalDistanceToNextPaddle;
        CGFloat verticalDistanceToNextPaddle = fabs(horizontalDistanceToNextPaddle) * reflectedBallDirection.y;
        newBallDestinationY = ballDestination.y + verticalDistanceToNextPaddle;
    } else {
        newBallDestinationX = ballDestination.x + horizontalDistanceToNextWall;
        newBallDestinationY = ballDestination.y + verticalDistanceToNextWall;
    }
    
    ballOrigin = ballDestination;
    ballDestination = CGPointMake(newBallDestinationX, newBallDestinationY);
    ballDirection = CGPointMake((ballDestination.x - ballOrigin.x), (ballDestination.y - ballOrigin.y));
    ballDirection = [self normalizeVector:ballDirection];
}

- (BOOL)didBallHitWall
{
    return ([self isFloat:ballDestination.y equalToFloat:[self ceilingContactY]] || [self isFloat:ballDestination.y equalToFloat:[self floorContactY]]);
}

- (BOOL)didBallHitPaddle
{
    return ([self isFloat:ballDestination.x equalToFloat:[self leftPaddleContactX]] || [self isFloat:ballDestination.x equalToFloat:[self rightPaddleContactX]]);
}

- (void)determineNextPaddleDestinations
{
    static CGFloat lazyFactor = 0.25f;
    static CGFloat normalFactor = 0.5f;
    static CGFloat holyCrapFactor = 1.0f;
    
    CGFloat leftPaddleVerticalDistanceToBallDestination = ballDestination.y - leftPaddleView.center.y;
    CGFloat rightPaddleVerticalDistanceToBallDestination = ballDestination.y - rightPaddleView.center.y;
    
    if(ballDirection.x < 0.0f) {
        //Going toward the left paddle
        
        //Destination is the left paddle
        if([self isFloat:ballDestination.x equalToFloat:[self leftPaddleContactX]]) {
            leftPaddleDestination = leftPaddleView.center.y + (leftPaddleVerticalDistanceToBallDestination * holyCrapFactor);
            rightPaddleDestination = rightPaddleView.center.y + (rightPaddleVerticalDistanceToBallDestination * lazyFactor);
        } else {
            //Destination is a wall
            leftPaddleDestination = leftPaddleView.center.y + (leftPaddleVerticalDistanceToBallDestination * normalFactor);
            rightPaddleDestination = rightPaddleView.center.y - (rightPaddleVerticalDistanceToBallDestination * normalFactor);
        }
    } else {
        //Going toward the right paddle
        
        //Destination is the right paddle
        if([self isFloat:ballDestination.x equalToFloat:[self rightPaddleContactX]]) {
            leftPaddleDestination = leftPaddleView.center.y + (leftPaddleVerticalDistanceToBallDestination * lazyFactor);
            rightPaddleDestination = rightPaddleView.center.y + (rightPaddleVerticalDistanceToBallDestination * holyCrapFactor);
        } else {
            //Destination is a wall
            leftPaddleDestination = leftPaddleView.center.y - (leftPaddleVerticalDistanceToBallDestination * normalFactor);
            rightPaddleDestination = rightPaddleView.center.y + (rightPaddleVerticalDistanceToBallDestination * normalFactor);
        }
    }
    
    if(leftPaddleDestination < [self ceilingLeftPaddleContactY]) {
        leftPaddleDestination = [self ceilingLeftPaddleContactY];
    } else if(leftPaddleDestination > [self floorLeftPaddleContactY]) {
        leftPaddleDestination = [self floorLeftPaddleContactY];
    }
    
    if(rightPaddleDestination < [self ceilingRightPaddleContactY]) {
        rightPaddleDestination = [self ceilingRightPaddleContactY];
    } else if(rightPaddleDestination > [self floorRightPaddleContactY]) {
        rightPaddleDestination = [self floorRightPaddleContactY];
    }
}

- (void)pickRandomBallDestination
{
    CGFloat destinationX = [self leftPaddleContactX];
    if(arc4random() % 2 == 1) {
        destinationX = [self rightPaddleContactX];
    }
    
    CGFloat destinationY = (float)(arc4random() % (int)self.frame.size.height);
    
    if(destinationY > 18.0f && destinationY <= self.frame.size.height / 2.0f) {
        destinationY -= 13.0f;
    } else if(destinationY >= self.frame.size.height / 2.0f && destinationY < self.frame.size.height - 18.0f) {
        destinationY += 13.0f;
    } else if(destinationY <= 5.0f) {
        destinationY = 5.0f;
    } else if(destinationY >= self.frame.size.height - 5.0f) {
        destinationY = self.frame.size.height - 5.0f;
    }
    
    ballDestination = CGPointMake(destinationX, destinationY);
    ballDirection = CGPointMake((ballDestination.x - ballOrigin.x), (ballDestination.y - ballOrigin.y));
    ballDirection = [self normalizeVector:ballDirection];
}

- (CGFloat)leftPaddleContactX
{
    return leftPaddleView.center.x + (ballView.frame.size.width / 2.0f);
}

- (CGFloat)rightPaddleContactX
{
    return rightPaddleView.center.x - (ballView.frame.size.width / 2.0f);
}

- (CGFloat)ceilingContactY
{
    return (ballView.frame.size.height / 2.0f);
}

- (CGFloat)floorContactY
{
    return self.frame.size.height - (ballView.frame.size.height / 2.0f);
}

- (CGFloat)ceilingLeftPaddleContactY
{
    return (leftPaddleView.frame.size.height / 2.0f);
}

- (CGFloat)floorLeftPaddleContactY
{
    return self.frame.size.height - (leftPaddleView.frame.size.height / 2.0f);
}

- (CGFloat)ceilingRightPaddleContactY
{
    return (rightPaddleView.frame.size.height / 2.0f);
}

- (CGFloat)floorRightPaddleContactY
{
    return self.frame.size.height - (rightPaddleView.frame.size.height / 2.0f);
}

#pragma mark - Etc

- (CGPoint)normalizeVector:(CGPoint)vector
{
    CGFloat magnitude = sqrtf(vector.x * vector.x + vector.y * vector.y);
    return CGPointMake(vector.x / magnitude, vector.y / magnitude);
}

- (BOOL)isFloat:(CGFloat)float1 equalToFloat:(CGFloat)float2
{
    static CGFloat ellipsis = 0.01f;
    
    return (fabsf(float1 - float2) < ellipsis);
}

@end