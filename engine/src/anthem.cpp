#include "anthem.h"

Anthem::Anthem() {
    engine = std::unique_ptr<tracktion::Engine>(new tracktion::Engine("anthem"));
}
