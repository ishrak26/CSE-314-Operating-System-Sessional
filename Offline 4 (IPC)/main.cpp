#include<bits/stdc++.h>
#include<pthread.h>
#include<semaphore.h>
#include<unistd.h>
#include<cstdint>

#include "poisson_random.hpp"

using namespace std;

#define PS_CNT 4 // no. of printing stations
#define MAX_STUD_CNT 100 // max. no. of students
#define BS_CNT 2 // no. of binding stations
#define STAFF_CNT 2 // no. of library staffs

const double POISSON_MEAN = 5.0;
const double POISSON_MEAN_STAFF = 10.0;

int N; // number of students
int M; // size of each group
int w; // relative time unit for printing
int x; // relative time unit for binding
int y; // relative time unit for reading/writing

Poisson_Random random_generator;

int curr_time;
pthread_mutex_t time_lock; // curr_time lock

// printing
pthread_mutex_t print_state_locks[PS_CNT]; // mutual exclusion of print state for each printing station
sem_t print_acquire[MAX_STUD_CNT]; // one semaphore per student for printing

enum print_state {
    NOT_ARRIVED,
    WAITING,
    PRINTING,
    PRINTED
};

print_state print_states[MAX_STUD_CNT]; // print state for each student

// binding
sem_t bind_needed[MAX_STUD_CNT]; // one semaphore for each group leader
sem_t bind_station; // semaphore for binding stations

// submission
int rc; // number of readers reading or wanting to
pthread_mutex_t entry_read; // controls access to rc
sem_t entry_book; // controls access to entry book
int submit_cnt;

// Initialize all semaphore and mutex
void init_semaphore()
{
	// time
    pthread_mutex_init(&time_lock,0);
    curr_time = 0;

    // printing
    for (int i = 0; i < PS_CNT; i++) {
        pthread_mutex_init(&print_state_locks[i],0);
    }
    for (int i = 0; i < N; i++) {
        sem_init(&print_acquire[i],1,0);
    }

    // binding
    for (int i = 0; i < N/M; i++) {
        sem_init(&bind_needed[i],1,0);
    }
    sem_init(&bind_station,1,BS_CNT);

    // submission
    rc = 0;
    submit_cnt = 0;
    pthread_mutex_init(&entry_read,0);
    sem_init(&entry_book,1,1);
}


// returns print_station id for a student 
int get_ps_id(int sid) {
    return (sid % PS_CNT) + 1;
} 

// returns id of the first groupmate
int get_group_id_lower(int sid) {
    int gid = (sid-1) / M;
    return M * gid + 1;
}

// returns id of the last groupmate
int get_group_id_higher(int sid) {
    int gid = (sid-1) / M;
    return M * (gid + 1);
}

// returns group id for a student
int get_group_id(int sid) {
    return 1 + (sid-1) / M;
}

void test_print(int sid, int ps_id) {
    bool flag = (print_states[sid-1] == WAITING);
    for (int i = (ps_id+2)%4; i < N && flag; i += PS_CNT) {
        if (print_states[i] == PRINTING) {
            // assigned printing station is occupied
            flag = false;
            break;
        } 
    }
    if (flag) {
        // assigned printing station is available for use
        print_states[sid-1] = PRINTING;
        sem_post(&print_acquire[sid-1]);
    }
}

void acquire_printer(int sid, int ps_id) {
    pthread_mutex_lock(&print_state_locks[ps_id-1]); // enter critical region
    print_states[sid-1] = WAITING; // record fact that this student is waiting to print
    test_print(sid, ps_id); // try to acquire printers if assigned printing station is not occupied
    pthread_mutex_unlock(&print_state_locks[ps_id-1]); // exit critical region
    sem_wait(&print_acquire[sid-1]); // block if printer could not be acquired
}

void release_printer(int sid, int ps_id) {
    pthread_mutex_lock(&print_state_locks[ps_id-1]); // enter critical region
    print_states[sid-1] = PRINTED; // this student has finished printing

    // try to assign printer to own groupmates
    int lo = get_group_id_lower(sid); 
    int hi = get_group_id_higher(sid);
    for (int i = lo; i <= hi; i++) {
        test_print(i, get_ps_id(i));
    }

    // now assign to everyone else
    for (int i = 1; i < lo; i++) {
        test_print(i, get_ps_id(i));
    }
    for (int i = hi+1; i < N; i++) {
        test_print(i, get_ps_id(i));
    }

    pthread_mutex_unlock(&print_state_locks[ps_id-1]); // exit critical region
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

    // try to print following Dining Philosopher problem
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

    int gid = get_group_id(sid);
    sem_post(&bind_needed[gid-1]); // notify the leader to bind
}

void * leader_func(void * arg) {
    int gid = (intptr_t) arg; // group id for this leader
    int thread_time;
    
    // wait for all group members to finish printing
    for (int i = 0; i < M; i++) {
        sem_wait(&bind_needed[gid-1]); // block if a student could not finish printing
    }

    pthread_mutex_lock(&time_lock);
    thread_time = curr_time;
    cout << "Group " << gid << " has finished printing at time " << thread_time << endl;
    pthread_mutex_unlock(&time_lock);

    sem_wait(&bind_station); // acquire a binding station, when free

    pthread_mutex_lock(&time_lock);
    thread_time = curr_time;
    cout << "Group " << gid << " has started binding at time " << thread_time << endl;
    pthread_mutex_unlock(&time_lock);

    // binding...
    sleep(x);

    pthread_mutex_lock(&time_lock);
    curr_time = max(curr_time, thread_time+x);
    thread_time = curr_time;
    cout << "Group " << gid << " has finished binding at time " << thread_time << endl;
    pthread_mutex_unlock(&time_lock);

    sem_post(&bind_station); // release binding station

    // submit 
    sem_wait(&entry_book); // get exclusive access to entry book
    
    // writing...
    sleep(y);

    submit_cnt++;

    // writing finished
    pthread_mutex_lock(&time_lock);
    curr_time = max(curr_time, thread_time+y);
    thread_time = curr_time;
    cout << "Group " << gid << " has submitted the report at time " << thread_time << endl;
    pthread_mutex_unlock(&time_lock);

    sem_post(&entry_book); // release exclusive access to entry book
}

void * staff_func(void * arg) {
    int staff_id = (intptr_t) arg;
    
    int thread_time;
    pthread_mutex_lock(&time_lock);
    thread_time = curr_time;
    pthread_mutex_unlock(&time_lock);

    int sc; // submission count
    Poisson_Random random_generator_staff(POISSON_MEAN_STAFF + random_generator.get_random_number());
    while (1) {
        // add random delay
        int delay = random_generator_staff.get_random_number();
        sleep(delay);
        pthread_mutex_lock(&time_lock);
        curr_time = max(curr_time, thread_time+delay);
        thread_time = curr_time;
        pthread_mutex_unlock(&time_lock);
        
        pthread_mutex_lock(&entry_read); // get exclusive access to rc
        rc++; // one reader more now
        if (rc == 1) {
            sem_wait(&entry_book); // this is the first reader
        }
        pthread_mutex_unlock(&entry_read); // release exclusive access to rc

        // read entry book
        pthread_mutex_lock(&time_lock);
        thread_time = curr_time;
        pthread_mutex_unlock(&time_lock);

        cout << "Staff " << staff_id << " has started reading the entry book at time " << thread_time << ". No. of submission = " << submit_cnt << endl;

        // reading...
        sleep(y); 

        pthread_mutex_lock(&time_lock);
        curr_time = max(curr_time, thread_time+y);
        thread_time = curr_time;
        cout << "Staff " << staff_id << " has finished reading the entry book at time " << thread_time << ". No. of submission = " << submit_cnt << endl;
        pthread_mutex_unlock(&time_lock);

        // reading finished
        pthread_mutex_lock(&entry_read); // get exclusive access to rc
        rc--; // one reader fewer now
        if (rc == 0) {
            sem_post(&entry_book); // this is the last reader
        }
        pthread_mutex_unlock(&entry_read); // release exclusive access to rc
    }
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

    pthread_t students[MAX_STUD_CNT];
    for (int i = 0; i < N; i++) {
        pthread_create(&students[i],NULL,student_func,(void*)(i+1));
    }

    pthread_t leaders[MAX_STUD_CNT];
    for (int i = 0; i < N/M; i++) {
        pthread_create(&leaders[i],NULL,leader_func,(void*)(i+1));
    }

    pthread_t staffs[STAFF_CNT];
    for (int i = 0; i < STAFF_CNT; i++) {
        pthread_create(&staffs[i],NULL,staff_func,(void*)(i+1));
    }

    pthread_exit(NULL);

    return 0;
}