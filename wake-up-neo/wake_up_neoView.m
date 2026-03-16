//
//  wake_up_neoView.m
//  wake-up-neo
//
//  Created by Anton Chernev on 16.03.26.
//

#import "wake_up_neoView.h"

static const CGFloat kFontSize        = 16.0;
static const CGFloat kPreviewFontSize = 8.0;
static const CGFloat kBrightnessDecay = 0.045;
static const CGFloat kSpawnChance     = 0.015;
static const CGFloat kMutateChance    = 0.004;

@interface wake_up_neoView () {
    int      _cols;
    int      _rows;
    CGFloat  _cellW;
    CGFloat  _cellH;
    CGFloat  _fontSize;

    // Flat grids (index = row * _cols + col)
    unichar *_charGrid;
    CGFloat *_brightGrid;

    // Per-column drop state
    int  *_headY;
    int  *_trail;
    int  *_speed;
    int  *_tick;
    BOOL *_active;

    NSFont *_font;
    BOOL    _needsSetup;
}
@end

@implementation wake_up_neoView

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self setAnimationTimeInterval:1.0 / 30.0];
        _fontSize   = isPreview ? kPreviewFontSize : kFontSize;
        _needsSetup = YES;
    }
    return self;
}

- (void)dealloc
{
    [self freeGrid];
}

- (BOOL)isFlipped
{
    return YES;
}

#pragma mark - Grid setup / teardown

- (void)setupGrid
{
    [self freeGrid];

    _font = [NSFont fontWithName:@"Menlo" size:_fontSize];
    if (!_font) {
        _font = [NSFont monospacedSystemFontOfSize:_fontSize weight:NSFontWeightRegular];
    }

    NSDictionary *attrs = @{NSFontAttributeName: _font};
    NSSize charSize = [@"W" sizeWithAttributes:attrs];
    _cellW = ceil(charSize.width);
    _cellH = ceil(charSize.height);

    NSSize size = self.bounds.size;
    _cols = MAX(1, (int)(size.width  / _cellW));
    _rows = MAX(1, (int)(size.height / _cellH));

    int total = _cols * _rows;

    _charGrid   = calloc(total, sizeof(unichar));
    _brightGrid = calloc(total, sizeof(CGFloat));
    _headY      = calloc(_cols, sizeof(int));
    _trail      = calloc(_cols, sizeof(int));
    _speed      = calloc(_cols, sizeof(int));
    _tick       = calloc(_cols, sizeof(int));
    _active     = calloc(_cols, sizeof(BOOL));

    for (int i = 0; i < total; i++) {
        _charGrid[i] = [self randomChar];
    }

    for (int c = 0; c < _cols; c++) {
        _active[c] = NO;
        _headY[c]  = -1;
    }

    _needsSetup = NO;
}

- (void)freeGrid
{
    if (_charGrid)   { free(_charGrid);   _charGrid   = NULL; }
    if (_brightGrid) { free(_brightGrid); _brightGrid = NULL; }
    if (_headY)      { free(_headY);      _headY      = NULL; }
    if (_trail)      { free(_trail);      _trail      = NULL; }
    if (_speed)      { free(_speed);      _speed      = NULL; }
    if (_tick)       { free(_tick);        _tick       = NULL; }
    if (_active)     { free(_active);     _active     = NULL; }
}

#pragma mark - Helpers

- (unichar)randomChar
{
    // 56 half-width katakana (U+FF66..FF9D) + 10 digits
    int choice = (int)arc4random_uniform(66);
    if (choice < 56) {
        return (unichar)(0xFF66 + choice);
    }
    return (unichar)('0' + (choice - 56));
}

- (int)randomIntFrom:(int)lo to:(int)hi
{
    return lo + (int)arc4random_uniform((uint32_t)(hi - lo + 1));
}

- (CGFloat)randomFloat
{
    return (CGFloat)arc4random() / (CGFloat)UINT32_MAX;
}

#pragma mark - Animation

- (void)startAnimation
{
    [super startAnimation];
    if (_needsSetup) {
        [self setupGrid];
    }
}

- (void)stopAnimation
{
    [super stopAnimation];
}

- (void)animateOneFrame
{
    if (_needsSetup || !_charGrid) {
        [self setupGrid];
    }

    int total = _cols * _rows;

    // 1. Fade all cells
    for (int i = 0; i < total; i++) {
        if (_brightGrid[i] > 0) {
            _brightGrid[i] -= kBrightnessDecay;
            if (_brightGrid[i] < 0) _brightGrid[i] = 0;
        }
    }

    // 2. Advance (or spawn) drops
    for (int c = 0; c < _cols; c++) {
        if (!_active[c]) {
            if ([self randomFloat] < kSpawnChance) {
                _active[c] = YES;
                _headY[c]  = 0;
                _trail[c]  = [self randomIntFrom:8 to:MAX(10, _rows)];
                _speed[c]  = [self randomIntFrom:1 to:4];
                _tick[c]   = 0;
            }
            continue;
        }

        _tick[c]++;
        if (_tick[c] < _speed[c]) continue;
        _tick[c] = 0;

        // Light up the head cell
        if (_headY[c] >= 0 && _headY[c] < _rows) {
            int idx = _headY[c] * _cols + c;
            _charGrid[idx]   = [self randomChar];
            _brightGrid[idx] = 1.0;
        }

        _headY[c]++;

        // Deactivate once the trail has scrolled off
        if (_headY[c] - _trail[c] > _rows) {
            _active[c] = NO;
        }
    }

    // 3. Randomly mutate visible characters
    for (int i = 0; i < total; i++) {
        if (_brightGrid[i] > 0.1 && [self randomFloat] < kMutateChance) {
            _charGrid[i] = [self randomChar];
        }
    }

    [self setNeedsDisplay:YES];
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)rect
{
    [[NSColor blackColor] setFill];
    NSRectFill(self.bounds);

    if (!_charGrid || !_brightGrid) return;

    for (int c = 0; c < _cols; c++) {
        for (int r = 0; r < _rows; r++) {
            int idx = r * _cols + c;
            CGFloat b = _brightGrid[idx];
            if (b < 0.02) continue;

            // Head of stream: bright white-green; trail: pure green fading out
            NSColor *color;
            if (b > 0.93) {
                color = [NSColor colorWithCalibratedRed:0.7 green:1.0 blue:0.7 alpha:1.0];
            } else {
                color = [NSColor colorWithCalibratedRed:0.0 green:b blue:0.0 alpha:1.0];
            }

            NSDictionary *attrs = @{
                NSFontAttributeName:            _font,
                NSForegroundColorAttributeName: color
            };

            unichar  ch  = _charGrid[idx];
            NSString *str = [NSString stringWithCharacters:&ch length:1];
            [str drawAtPoint:NSMakePoint(c * _cellW, r * _cellH) withAttributes:attrs];
        }
    }
}

#pragma mark - Configuration

- (BOOL)hasConfigureSheet
{
    return NO;
}

- (NSWindow *)configureSheet
{
    return nil;
}

@end
