// Duo 시뮬레이터 접기·펴기 제어 도구 (iOS 시뮬레이터 전용, 테스트 용도).
//
// Xcode 27.2 시뮬레이터 앱(DeviceHub)에는 접기 메뉴가 없어서, Duo 런타임 안 SpringBoard의
// 디스플레이 테스트 서비스(SBSDisplayToolService, 비공개 API)를 직접 부른다.
// 앱에 들어가는 코드가 아니며, 런타임이 바뀌면 동작하지 않을 수 있다.
//
//   xcrun simctl spawn <기기> duotool swap -position=open -duration=0 -deviceOrientation=portrait -wait
//   xcrun simctl spawn <기기> duotool usage
//
// -position: closed(바깥 화면) | open(안쪽 화면) | book(반쯤 접기, 약 100°) | 0.0~1.0
// -deviceOrientation: 기기 기준 방향 — portrait로 펼치면 안쪽 화면은 가로, landscapeLeft로 펼치면 세로
// 서비스 접근에는 com.apple.springboard.sbdisplay.service 엔타이틀먼트가 필요하다 (build.sh가 섹션에 넣음).
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <dlfcn.h>

/// SBFDisplayToolSwapSettings ({q d q q B q d d}, 64바이트). 값은 SBFDisplayToolSwapSettingsFromArguments가 채운다.
typedef struct {
    long long kind;
    double duration;          // -1 = 미지정
    long long deviceOrientation;
    long long profileOverride; // fade / continuous
    BOOL wait;
    long long hasPosition;
    double position;          // 0 = closed, 1 = open
    double reserved;
} SwapSettings;

/// (args, &settings, &error) — 결과는 두 번째 인자로 받는다. 반환형이 공개돼 있지 않아 무시한다.
typedef void (*SwapSettingsParser)(NSArray<NSString *> *, SwapSettings *, void *);
typedef id (*UsageFn)(void);

static void loadFrameworks(void) {
    dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);
    dlopen("/System/Library/PrivateFrameworks/SpringBoardFoundation.framework/SpringBoardFoundation", RTLD_NOW);
}

int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        loadFrameworks();
        NSString *cmd = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : @"usage";
        NSMutableArray<NSString *> *rest = [NSMutableArray array];
        for (int i = 2; i < argc; i++) [rest addObject:[NSString stringWithUTF8String:argv[i]]];

        if ([cmd isEqualToString:@"usage"]) {
            UsageFn usage = (UsageFn)dlsym(RTLD_DEFAULT, "SBFDisplayToolSwapSettingsUsageDescription");
            printf("duotool swap|lock|unlock|usage\n\n%s\n", usage ? [[usage() description] UTF8String] : "(usage 없음 — Duo 런타임이 아닌 것 같습니다)");
            return 0;
        }

        Class serviceClass = NSClassFromString(@"SBSDisplayToolService");
        if (!serviceClass) { fprintf(stderr, "SBSDisplayToolService 없음 — iPhone Duo 런타임(iOS 27.1+)에서 실행하세요\n"); return 2; }
        id service = [[serviceClass alloc] init];

        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block NSString *result = @"ok";
        void (^completion)(id) = ^(id error) {
            if (error) result = [error description];
            dispatch_semaphore_signal(done);
        };

        if ([cmd isEqualToString:@"swap"]) {
            SwapSettingsParser parse = (SwapSettingsParser)dlsym(RTLD_DEFAULT, "SBFDisplayToolSwapSettingsFromArguments");
            if (!parse) { fprintf(stderr, "SBFDisplayToolSwapSettingsFromArguments 없음\n"); return 2; }
            SwapSettings settings; memset(&settings, 0, sizeof settings);
            static unsigned char errorSlot[256];   // 오류 출력 인자 — 형식이 공개돼 있지 않아 넉넉한 버퍼로 받는다
            memset(errorSlot, 0, sizeof errorSlot);
            parse(rest, &settings, errorSlot);
            ((void (*)(id, SEL, SwapSettings, id))objc_msgSend)(service, NSSelectorFromString(@"swapDisplayWithSettings:completionHandler:"), settings, completion);
        } else if ([cmd isEqualToString:@"lock"]) {
            ((void (*)(id, SEL, id))objc_msgSend)(service, NSSelectorFromString(@"lockForTestingWithCompletion:"), completion);
        } else if ([cmd isEqualToString:@"unlock"]) {
            ((void (*)(id, SEL, id))objc_msgSend)(service, NSSelectorFromString(@"unlockForTestingWithCompletion:"), completion);
        } else {
            fprintf(stderr, "알 수 없는 명령: %s\n", cmd.UTF8String);
            return 1;
        }

        long timedOut = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC));
        printf("%s -> %s%s\n", cmd.UTF8String, result.UTF8String, timedOut ? " (timeout)" : "");
        ((void (*)(id, SEL))objc_msgSend)(service, NSSelectorFromString(@"invalidate"));
        return [result isEqualToString:@"ok"] && !timedOut ? 0 : 1;
    }
}
