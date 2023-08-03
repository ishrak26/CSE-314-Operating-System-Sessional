#include<bits/stdc++.h>
#include<pthread.h>
#include<semaphore.h>
#include<unistd.h>
#include <cstdint>

#include "poisson_random.hpp"

using namespace std;

#define PS_CNT 4 // no. of printing stations
#define MAX_STUD_CNT 100 // max. no. of students

const double POISSON_MEAN = 3.0;

int N; // number of students
int M; // size of each group
int w; // relative time unit for printing
int x; // relative time unit for binding
int y; // relative time unit for reading/writing

int curr_time;

pthread_mutex_t time_lock; // curr_time lock
pthread_mutex_t print_state_locks[PS_CNT];
sem_t print_acquire[MAX_STUD_CNT];

Poisson_Random random_generator;

enum print_state {
    NOT_ARRIVED,
    WAITING,
    PRINTING,
    PRINTED
};

print_state print_states[MAX_STUD_CNT];

/*
    Initialize all semaphore and mutex
*/
void init_semaphore()
{
	pthread_mutex_init(&time_lock,0);
    curr_time = 0;
    for (int i = 0; i < PS_CNT; i++) {
        pthread_mutex_init(&print_state_locks[i],0);
    }
    for (int i = 0; i < N; i++) {
        sem_init(&print_acquire[i],1,0);
    }
}

/*
    returns print_station id for a student 
*/
int get_ps_id(int sid) {
    return (sid % PS_CNT) + 1;
} 

int get_group_id_lower(int sid) {
    int gid = (sid-1) / M;
    return M * gid + 1;
}

int get_group_id_higher(int sid) {
    int gid = (sid-1) / M;
    return M * (gid + 1);
}

void test_print(int sid, int ps_id) {
    bool flag = (print_states[sid-1] == WAITING);
    for (int i = (ps_id+2)%4; i < N && flag; i += PS_CNT) {
        if (print_states[i] == PRINTING) {
            flag = false;
            break;
        } 
    }
    if (flag) {
        print_states[sid-1] = PRINTING;
        
        // pthread_mutex_lock(&time_lock);
        // int t = curr_time;
        // pthread_mutex_unlock(&time_lock);
        // cout << "Before sem_post: " << sid << " " << ps_id << " " << t << endl;
        sem_post(&print_acquire[sid-1]);
        // pthread_mutex_lock(&time_lock);
        // t = curr_time;
        // pthread_mutex_unlock(&time_lock);
        // cout << "After sem_post: " << sid << " " << ps_id << " " << t << endl;
    }
}

void acquire_printer(int sid, int ps_id) {
    pthread_mutex_lock(&print_state_locks[ps_id-1]);
    print_states[sid-1] = WAITING;
    test_print(sid, ps_id);
    pthread_mutex_unlock(&print_state_locks[ps_id-1]);
    
    // pthread_mutex_lock(&time_lock);
    // int t = curr_time;
    // pthread_mutex_unlock(&time_lock);
    // cout << "Before sem_wait: " << sid << " " << ps_id << " " << t << endl;
    sem_wait(&print_acquire[sid-1]);
    // pthread_mutex_lock(&time_lock);
    // t = curr_time;
    // pthread_mutex_unlock(&time_lock);
    // cout << "After sem_wait: " << sid << " " << ps_id << " " << t << endl;
}

void release_printer(int sid, int ps_id) {
    pthread_mutex_lock(&print_state_locks[ps_id-1]);
    print_states[sid-1] = PRINTED;
    int lo = get_group_id_lower(sid);
    int hi = get_group_id_higher(sid);
    for (int i = lo; i <= hi; i++) {
        test_print(i, get_ps_id(i));
    }
    for (int i = 1; i < lo; i++) {
        test_print(i, get_ps_id(i));
    }
    for (int i = hi+1; i < N; i++) {
        test_print(i, get_ps_id(i));
    }
    pthread_mutex_unlock(&print_state_locks[ps_id-1]);
}

void * student_func(void * arg) {
    int sid = (intptr_t) arg;
    int thread_time;

    pthread_mutex_lock(&time_lock);
    thread_time = curr_time;
    pthread_mutex_unlock(&time_lock);

    // initiate random delay
    int delay = random_generator.get_random_number(); 
    // no need for lock, since order of random number doesn't matter
    sleep(delay);

    pthread_mutex_lock(&time_lock);
    curr_time = max(curr_time, thread_time+delay);
    thread_time = curr_time;
    cout << "Student " << sid << " has arrived at the print station at time " << thread_time << endl;
    pthread_mutex_unlock(&time_lock);

    // try to print
    int ps_id = get_ps_id(sid);

    acquire_printer(sid, ps_id);

    // time when he got the printer
    pthread_mutex_lock(&time_lock);
    thread_time = curr_time;
    // cout << "Student " << sid << " has acquired printer at time " << thread_time << endl;
    pthread_mutex_unlock(&time_lock);
    
    // printing...
    sleep(w);

    // finished printing
    pthread_mutex_lock(&time_lock);
    curr_time = max(curr_time, thread_time+w);
    thread_time = curr_time;
    cout << "Student " << sid << " has finished printing at time " << thread_time << endl;
    pthread_mutex_unlock(&time_lock);

    release_printer(sid, ps_id);
}

int main() {
    freopen("input.txt", "r", stdin);
    freopen("output.txt", "w", stdout);
    cin >> N >> M >> w >> x >> y;

    if (N <= 0 || M <= 0 || w < 0 || x < 0 || y < 0) {
        cout << "Invalid input!" << endl;
        return 1;
    }

    if (N > MAX_STUD_CNT) {
        cout << "Maximum allowed number of students is " << MAX_STUD_CNT << endl;
        return 1;
    }

    if (N % M != 0) {
        cout << "M must be divisible by N" << endl;
        return 1;
    }

    init_semaphore();

    random_generator = Poisson_Random(POISSON_MEAN);

    pthread_t student[MAX_STUD_CNT];
    for (int i = 0; i < N; i++) {
        pthread_create(&student[i],NULL,student_func,(void*)(i+1));
    }

    pthread_exit(NULL);

    return 0;
}