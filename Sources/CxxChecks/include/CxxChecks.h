#ifndef CXX_CHECKS_H
#define CXX_CHECKS_H

#ifdef __cplusplus
extern "C" {
#endif

/// Each function returns 1 on success and 0 on failure.
int cxx_check_throw_catch(void);
int cxx_check_catch_base(void);
int cxx_check_rethrow(void);
int cxx_check_exception_ptr(void);
int cxx_check_bad_alloc(void);
int cxx_check_dynamic_cast(void);
int cxx_check_typeid(void);
int cxx_check_static_init_threads(void);
int cxx_check_nested(void);
int cxx_check_future_async(void);
int cxx_check_promise_thread(void);
int cxx_check_swift_exception_bridge(void);

#ifdef __cplusplus
}
#endif

#endif
