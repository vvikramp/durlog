CC     = clang
CFLAGS = -std=c17 -Wall -Wextra -g -MMD -MP -fsanitize=address,undefined -Iinclude -I$(SRC_DIR)/headers

# Folders
SRC_DIR = src
BUILD_DIR = build
TEST_DIR  = tests

LIB_SRCS = $(wildcard $(SRC_DIR)/impls/*.c) # every c file under impls/ 
LIB_OBJS = $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.o, $(LIB_SRCS))

MAIN_OBJ = $(BUILD_DIR)/main.o #

# Tests: each tests/*.c is its own program with its own main().
TEST_SRCS = $(wildcard $(TEST_DIR)/*.c)
TEST_OBJS = $(patsubst $(TEST_DIR)/%.c, $(BUILD_DIR)/tests/%.o, $(TEST_SRCS))
TEST_BINS = $(patsubst %.o, %, $(TEST_OBJS))

DEPS = $(LIB_OBJS:.o=.d) $(MAIN_OBJ:.o=.d) $(TEST_OBJS:.o=.d)

all: durlog $(TEST_BINS)

durlog: $(LIB_OBJS) $(MAIN_OBJ) # link all .o files into the program
	$(CC) $(CFLAGS) -o $@ $^

$(TEST_BINS): $(BUILD_DIR)/tests/%: $(BUILD_DIR)/tests/%.o $(LIB_OBJS)
	$(CC) $(CFLAGS) -o $@ $^

test: $(TEST_BINS)
	@fail=0; \
	for t in $(TEST_BINS); do \
		echo "== $$t"; \
		$$t || { echo "FAIL: $$t"; fail=1; }; \
	done; \
	exit $$fail

${BUILD_DIR}/%.o: ${SRC_DIR}/%.c # compile any .c into a .o
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/tests/%.o: $(TEST_DIR)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

run: durlog
	./durlog

clean:
	rm -rf $(BUILD_DIR) durlog durlog.dSYM

-include $(DEPS)

.PHONY: run clean