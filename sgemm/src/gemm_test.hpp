#include "lib/test.hpp"

class GemmTest : public BaseTest {
    const size_t M;
    const size_t N;
    const size_t K;
    float* cpu_A; // M * K in device
    float* cpu_B; // K * N
    float* cpu_C;
    float* cublas_output;
    float* my_output;
    float* gpu_A;
    float* gpu_B;
    float* gpu_C;
    bool baseline_runned = false;
public:
    GemmTest(size_t _M, size_t _N, size_t _K, 
            const string& _kernel_name, uint _repeat_nums) : 
        BaseTest(2*_M*_N*_K, _kernel_name, _repeat_nums),
        M(_M), N(_N), K(_K) {
        cpu_A = static_cast<float*>(malloc(M * K * sizeof(float)));
		cpu_B = static_cast<float*>(malloc(K * N * sizeof(float)));
		cpu_C = static_cast<float*>(malloc(M * N * sizeof(float)));
        cublas_output = static_cast<float*>(malloc(M * N * sizeof(float)));
        my_output = static_cast<float*>(malloc(M * N * sizeof(float)));
        auto sta = std::chrono::steady_clock::now();
		GenerateRandomMatrix(cpu_A, M * K);
		GenerateRandomMatrix(cpu_B, K * N);
        GenerateRandomMatrix(cpu_C, M * N);
		std::chrono::nanoseconds rand_duration = std::chrono::steady_clock::now() - sta;
		clog << "[Generate Random Input Matrix]\tTimeCost:" << std::chrono::duration_cast<microseconds>(rand_duration).count() << "us" << std::endl;
    }
    virtual ~GemmTest() {
        free(cpu_A);
		free(cpu_B);
		free(cpu_C);
        free(cublas_output);
        free(my_output);
        if (baseline_runned) {
            CUDA_CHECK(cudaFree(gpu_A));
            CUDA_CHECK(cudaFree(gpu_B));
            CUDA_CHECK(cudaFree(gpu_C));
        }
    }
    virtual void run_baseline() {
        CUDA_CHECK(cudaMalloc((void **)&gpu_A, M * K * sizeof(float)));
        CUDA_CHECK(cudaMalloc((void **)&gpu_B, K * N * sizeof(float)));
        CUDA_CHECK(cudaMalloc((void **)&gpu_C, M * N * sizeof(float)));
        cublasStatus_t stat;   // cuBLAS functions status
        cublasHandle_t handle; // cuBLAS context
        stat = cublasCreate(&handle); // initialize CUBLAS context
        cudaMemcpy(gpu_A, cpu_A, M * K * sizeof(float), cudaMemcpyHostToDevice);
        cudaMemcpy(gpu_B, cpu_B, K * N * sizeof(float), cudaMemcpyHostToDevice);
        cudaMemcpy(gpu_C, cpu_C, M * N * sizeof(float), cudaMemcpyHostToDevice);
        float alpha = 1.0f;
        float beta = 0.5f;
    
        auto sta = std::chrono::steady_clock::now();
        for(int i = 0; i < repeat_nums; i++) {
            stat = cublasSgemm(handle, CUBLAS_OP_N, CUBLAS_OP_N, N, M, K, 
                &alpha, gpu_B, N, gpu_A, K, &beta, gpu_C, N);
        }
		std::chrono::nanoseconds cublas_duration = std::chrono::steady_clock::now() - sta;
		// clog << "[cublas_sgemm]\tTimeCost:" << std::chrono::duration_cast<microseconds>(cublas_duration).count() << "us" << std::endl;
        print_performance_result(cublas_duration, "cublas");
        cudaMemcpy(cublas_output, gpu_C, M * N * sizeof(float), cudaMemcpyDeviceToHost);
        baseline_runned = true;
    }
};