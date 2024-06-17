#import <UIKit/UIKit.h>
#include <substrate.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <spawn.h>

int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
int csops_audittoken(pid_t pid, unsigned int ops, void * useraddr, size_t usersize, audit_token_t * token);
bool os_variant_has_internal_content(const char* subsystem);
int ptrace(int, int, int, int);
uint32_t SecTaskGetCodeSignStatus();

int (*orig_csops)(pid_t pid, unsigned int  ops, void * useraddr, size_t usersize);
int (*orig_csops_audittoken)(pid_t pid, unsigned int  ops, void * useraddr, size_t usersize, audit_token_t * token);

// JIT
#define CS_DEBUGGED 0x10000000
#define PT_TRACE_ME 0
#define PT_DETACH 11
int fork();
static int isJITEnabled() {
    int flags;
    csops(getpid(), 0, &flags, sizeof(flags));
    return (flags & CS_DEBUGGED) != 0;
}

uint32_t hooked_SecTaskGetCodeSignStatus() {
    return 0x36803809; // CS_PLATFORM_BINARY
}

bool hooked_os_variant_has_internal_content(const char* subsystem) {
	 return true;
}

int (*SBSystemAppMain)(int argc, char *argv[], char *envp[]);

int main(int argc, char *argv[], char *envp[]) {
    if (!isJITEnabled() && argc == 2) {
        int ret = ptrace(PT_TRACE_ME, 0, 0, 0);
        return ret;
    } else if (!isJITEnabled()) {
        int pid;
        int ret = posix_spawnp(&pid, argv[0], NULL, NULL, (char *[]){argv[0], "", NULL}, envp);
        if (ret == 0) {
            // Cleanup child process
            waitpid(pid, NULL, WUNTRACED);
            ptrace(PT_DETACH, pid, 0, 0);
            kill(pid, SIGTERM);
            wait(NULL);
        }
    }

    assert(isJITEnabled());
    MSHookFunction(&SecTaskGetCodeSignStatus, &hooked_SecTaskGetCodeSignStatus, NULL);
    MSHookFunction(&os_variant_has_internal_content, &hooked_os_variant_has_internal_content, NULL);

    [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"SBDontLockAfterCrash"];
    void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoard.framework/SpringBoard", RTLD_GLOBAL);

    void *tweakHandle = dlopen("@executable_path/SpringBoardTweak.dylib", RTLD_GLOBAL|RTLD_NOW);
    if (!tweakHandle) {
        //[@(dlerror()) writeToFile:@"/tmp/AAAAA.txt" atomically:YES];
        abort();
    }

    //dlopen("/var/jb/usr/lib/TweakInject/FLEXing.dylib", RTLD_GLOBAL|RTLD_NOW);
    SBSystemAppMain = dlsym(handle, "SBSystemAppMain");
	 return SBSystemAppMain(argc, argv, envp);
}
