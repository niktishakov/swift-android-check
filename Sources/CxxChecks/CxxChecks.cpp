#include "CxxChecks.h"

#include <atomic>
#include <cstring>
#include <exception>
#include <future>
#include <new>
#include <stdexcept>
#include <string>
#include <thread>
#include <typeinfo>
#include <vector>

namespace {

struct Base {
  virtual ~Base() = default;
};

struct Derived : Base {
  int value = 42;
};

struct ProbeError : std::runtime_error {
  explicit ProbeError(int code) : std::runtime_error("probe error"), code(code) {}
  int code;
};

Base *makeObject(bool derived) {
  if (derived)
    return new Derived();
  return new Base();
}

std::atomic<int> constructions{0};

struct Counted {
  Counted() { constructions.fetch_add(1); }
};

Counted &sharedCounted() {
  static Counted instance;
  return instance;
}

} // namespace

extern "C" int cxx_check_throw_catch(void) {
  try {
    throw std::runtime_error("hello");
  } catch (const std::runtime_error &error) {
    return std::strcmp(error.what(), "hello") == 0;
  }
  return 0;
}

extern "C" int cxx_check_catch_base(void) {
  try {
    throw ProbeError(7);
  } catch (const std::exception &error) {
    const auto *probe = dynamic_cast<const ProbeError *>(&error);
    return probe != nullptr && probe->code == 7;
  }
  return 0;
}

extern "C" int cxx_check_rethrow(void) {
  try {
    try {
      throw std::logic_error("inner");
    } catch (...) {
      throw;
    }
  } catch (const std::logic_error &error) {
    return std::strcmp(error.what(), "inner") == 0;
  }
  return 0;
}

extern "C" int cxx_check_exception_ptr(void) {
  std::exception_ptr stored;
  std::thread([&] {
    try {
      throw ProbeError(3);
    } catch (...) {
      stored = std::current_exception();
    }
  }).join();
  try {
    std::rethrow_exception(stored);
  } catch (const ProbeError &error) {
    return error.code == 3;
  }
  return 0;
}

extern "C" int cxx_check_bad_alloc(void) {
  try {
    std::vector<char> huge;
    huge.reserve(static_cast<size_t>(-1) / 2);
  } catch (const std::length_error &) {
    return 1;
  } catch (const std::bad_alloc &) {
    return 1;
  }
  return 0;
}

extern "C" int cxx_check_dynamic_cast(void) {
  Base *derived = makeObject(true);
  Base *base = makeObject(false);
  bool ok = dynamic_cast<Derived *>(derived) != nullptr &&
            dynamic_cast<Derived *>(derived)->value == 42 &&
            dynamic_cast<Derived *>(base) == nullptr;
  try {
    Base &ref = *base;
    (void)dynamic_cast<Derived &>(ref);
    ok = false;
  } catch (const std::bad_cast &) {
  }
  delete derived;
  delete base;
  return ok;
}

extern "C" int cxx_check_typeid(void) {
  Base *derived = makeObject(true);
  bool ok = typeid(*derived) == typeid(Derived) && typeid(*derived) != typeid(Base);
  try {
    Base *null = nullptr;
    (void)typeid(*null);
    ok = false;
  } catch (const std::bad_typeid &) {
  }
  delete derived;
  return ok;
}

extern "C" int cxx_check_static_init_threads(void) {
  std::vector<std::thread> threads;
  for (int i = 0; i < 8; ++i)
    threads.emplace_back([] { (void)sharedCounted(); });
  for (auto &thread : threads)
    thread.join();
  return constructions.load() == 1;
}

extern "C" int cxx_check_nested(void) {
  try {
    try {
      throw std::runtime_error("first");
    } catch (...) {
      std::throw_with_nested(std::logic_error("second"));
    }
  } catch (const std::logic_error &outer) {
    try {
      std::rethrow_if_nested(outer);
    } catch (const std::runtime_error &inner) {
      return std::strcmp(inner.what(), "first") == 0 &&
             std::strcmp(outer.what(), "second") == 0;
    }
  }
  return 0;
}

// The future checks return 1 on success, 0 when get() returned without throwing,
// 2 when the expected exception type arrived with the wrong contents and
// 3 when an exception of another type arrived.
extern "C" int cxx_check_future_async(void) {
  auto result = std::async(std::launch::async, []() -> int { throw ProbeError(5); });
  try {
    (void)result.get();
  } catch (const ProbeError &error) {
    return error.code == 5 ? 1 : 2;
  } catch (...) {
    return 3;
  }
  return 0;
}

extern "C" int cxx_check_promise_thread(void) {
  std::promise<int> promise;
  auto result = promise.get_future();
  std::thread([&promise] {
    try {
      throw std::runtime_error("from worker");
    } catch (...) {
      promise.set_exception(std::current_exception());
    }
  }).join();
  try {
    (void)result.get();
  } catch (const std::runtime_error &error) {
    return std::strcmp(error.what(), "from worker") == 0 ? 1 : 2;
  } catch (...) {
    return 3;
  }
  return 0;
}
