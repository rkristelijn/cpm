/* runner.c — Parallel task runner using fork/waitpid.
 *
 * Forks all tasks at once, waits for all, collects results.
 * Output is buffered per-task to avoid interleaving.
 */
#include "runner.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <unistd.h>

bool cpm_has_tool(const char *name) {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "command -v %s >/dev/null 2>&1", name);
    return system(cmd) == 0;
}

int cpm_exec(const char *cmd) {
    int ret = system(cmd);
    if (WIFEXITED(ret)) return WEXITSTATUS(ret);
    return 1;
}

int cpm_changed_files(char files[][256], int max) {
    FILE *p = popen("git diff --name-only HEAD 2>/dev/null", "r");
    if (!p) return 0;
    int count = 0;
    while (count < max && fgets(files[count], 256, p))  {
        /* strip newline */
        files[count][strcspn(files[count], "\n")] = '\0';
        if (files[count][0]) count++;
    }
    pclose(p);
    return count;
}

static double now_sec(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec / 1e6;
}

RunSummary cpm_run_parallel(const char **names, const char **commands,
                            const bool *warn_only, int count) {
    RunSummary s = {};
    s.results = (RunResult *)calloc(count, sizeof(RunResult));
    s.count = count;

    pid_t *pids = (pid_t *)calloc(count, sizeof(pid_t));
    int (*pipes)[2] = (int (*)[2])calloc(count, sizeof(int[2]));
    double start = now_sec();

    for (int i = 0; i < count; i++) {
        s.results[i].name = names[i];
        s.results[i].command = commands[i];
        s.results[i].warn_only = warn_only[i];

        if (!commands[i] || !commands[i][0]) {
            s.results[i].skipped = true;
            s.skipped++;
            pids[i] = -1;
            continue;
        }

        pipe(pipes[i]);
        pids[i] = fork();

        if (pids[i] == 0) {
            /* child: redirect stdout+stderr to pipe */
            close(pipes[i][0]);
            dup2(pipes[i][1], STDOUT_FILENO);
            dup2(pipes[i][1], STDERR_FILENO);
            close(pipes[i][1]);
            int rc = system(commands[i]);
            _exit(WIFEXITED(rc) ? WEXITSTATUS(rc) : 1);
        }
        close(pipes[i][1]);
    }

    /* Wait for all children, print results in order */
    for (int i = 0; i < count; i++) {
        if (pids[i] <= 0) continue;

        double t0 = now_sec();
        int status;
        waitpid(pids[i], &status, 0);
        s.results[i].elapsed_sec = now_sec() - t0;
        s.results[i].exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : 1;

        /* Read child output */
        char buf[4096];
        ssize_t n;
        while ((n = read(pipes[i][0], buf, sizeof(buf) - 1)) > 0) {
            buf[n] = '\0';
            /* Only print output on failure */
            if (s.results[i].exit_code != 0) fputs(buf, stderr);
        }
        close(pipes[i][0]);

        if (s.results[i].exit_code == 0) {
            s.passed++;
        } else if (s.results[i].warn_only) {
            s.warned++;
        } else {
            s.failed++;
        }
    }

    s.total_sec = now_sec() - start;
    free(pids);
    free(pipes);
    return s;
}
