extends CanvasLayer

@onready var option_button: OptionButton = $OptionButton
@onready var title_label: RichTextLabel = $RichTextLabel
@onready var content_label: RichTextLabel = $ScrollContainer/RichTextLabel2
@onready var back_button: TextureButton = get_node_or_null("Back")

# --- Your original untouched titles (inherits 100% of your inspector font/color changes) ---
const TITLES = [
	"[center] BUBBLE SORT [/center]",
	"[center] SELECTION SORT [/center]",
	"[center] SHELL SORT [/center]",
	"[center] HEAP SORT [/center]",
	"[center] BUCKET SORT [/center]",
	"[center] RADIX SORT [/center]",
]

const CONTENTS = [
	# --- BUBBLE SORT ---
	"[color=#00FFED][font_size=22][b]1. How it works[/b][/font_size][/color]
Bubble Sort repeatedly steps through the list, compares adjacent elements, and swaps them if they are in the wrong order. The largest unsorted element [b]\"bubbles up\"[/b] to its correct position after each pass. This repeats until no swaps are needed.

[table=2, #141f21]
[cell]  [color=#a0a0a0]Time Complexity:[/color]  [/cell][cell]  [color=#00FFED]O(n²) avg/worst, O(n) best[/color]  [/cell]
[cell]  [color=#a0a0a0]Space Complexity:[/color]  [/cell][cell]  [color=#00FFED]O(1) Auxiliary[/color]  [/cell]
[/table]


[color=#00FFED][font_size=22][b]2. Step-by-step example with [5, 3, 8, 1][/b][/font_size][/color]
[b]Pass 1:[/b]
  • Compare 5 and 3 → [color=#ff5555]swap[/color] → [3, 5, 8, 1]
  • Compare 5 and 8 → no swap → [3, 5, 8, 1]
  • Compare 8 and 1 → [color=#ff5555]swap[/color] → [3, 5, 1, [b]8[/b]]
[b]Pass 2:[/b]
  • Compare 3 and 5 → no swap → [3, 5, 1, [b]8[/b]]
  • Compare 5 and 1 → [color=#ff5555]swap[/color] → [3, 1, [b]5[/b], [b]8[/b]]
[b]Pass 3:[/b]
  • Compare 3 and 1 → [color=#ff5555]swap[/color] → [[b]1[/b], [b]3[/b], [b]5[/b], [b]8[/b]]
[b]Done:[/b] [color=#00FFED][1, 3, 5, 8][/color]


[color=#00FFED][font_size=22][b]3. Pseudocode[/b][/font_size][/color]
[font_size=18]
[color=#ff79c6]FUNC[/color] [color=#50fa7b]bubbleSort[/color](AR):
    [color=#f1fa8c]LET[/color] n = AR.length
    [color=#f1fa8c]LET[/color] swapped = [color=#bd93f9]TRUE[/color]
    [color=#ff79c6]WHILE[/color] swapped:
        swapped = [color=#bd93f9]FALSE[/color]
        [color=#ff79c6]FOR[/color] j [color=#ff79c6]FROM[/color] 0 [color=#ff79c6]TO[/color] n-2:
            [color=#ff79c6]IF[/color] AR[j] > AR[j+1]:
                [color=#50fa7b]SWAP[/color](AR[j], AR[j+1])
                swapped = [color=#bd93f9]TRUE[/color]
    [color=#ff79c6]RETURN[/color] AR
[color=#a0a0a0]Reference:[/color] [url=https://www.geeksforgeeks.org/dsa/bubble-sort-algorithm/]GeeksForGeeks - Bubble Sort[/url]",

	# --- SELECTION SORT ---
	"[color=#00FFED][font_size=22][b]1. How it works[/b][/font_size][/color]
Selection Sort divides the list into a sorted and unsorted portion. It repeatedly finds the minimum element from the unsorted portion and places it at the end of the sorted portion. Unlike Bubble Sort, it makes fewer swaps.

[table=2, #141f21]
[cell]  [color=#a0a0a0]Time Complexity:[/color]  [/cell][cell]  [color=#00FFED]O(n²) Always[/color]  [/cell]
[cell]  [color=#a0a0a0]Space Complexity:[/color]  [/cell][cell]  [color=#00FFED]O(1) Auxiliary[/color]  [/cell]
[/table]


[color=#00FFED][font_size=22][b]2. Step-by-step example with [5, 3, 8, 1][/b][/font_size][/color]
[b]Pass 1:[/b]
  • Find minimum in [5, 3, 8, 1] → [b]1[/b]
  • Swap 1 with 5 → [[b]1[/b], 3, 8, 5]
[b]Pass 2:[/b]
  • Find minimum in [3, 8, 5] → [b]3[/b]
  • Already in place → [[b]1[/b], [b]3[/b], 8, 5]
[b]Pass 3:[/b]
  • Find minimum in [8, 5] → [b]5[/b]
  • Swap 5 with 8 → [[b]1[/b], [b]3[/b], [b]5[/b], [b]8[/b]]
[b]Done:[/b] [color=#00FFED][1, 3, 5, 8][/color]


[color=#00FFED][font_size=22][b]3. Pseudocode[/b][/font_size][/color]
[font_size=18]
[color=#ff79c6]FUNC[/color] [color=#50fa7b]selectionSort[/color](AR):
    [color=#f1fa8c]LET[/color] n = AR.length
    [color=#ff79c6]FOR[/color] i [color=#ff79c6]FROM[/color] 0 [color=#ff79c6]TO[/color] n-1:
        [color=#f1fa8c]LET[/color] minIdx = i
        [color=#ff79c6]FOR[/color] j [color=#ff79c6]FROM[/color] i+1 [color=#ff79c6]TO[/color] n-1:
            [color=#ff79c6]IF[/color] AR[j] < AR[minIdx]:
                minIdx = j
        [color=#50fa7b]SWAP[/color](AR[i], AR[minIdx])
    [color=#ff79c6]RETURN[/color] AR
[color=#a0a0a0]Reference:[/color] [url=https://www.geeksforgeeks.org/dsa/selection-sort-algorithm-2/]GeeksForGeeks - Selection Sort[/url]",

	# --- SHELL SORT ---
	"[color=#00FFED][font_size=22][b]1. How it works[/b][/font_size][/color]
Shell Sort is an improved version of Insertion Sort. Instead of comparing adjacent elements, it compares elements that are far apart using a [b]gap[/b]. The gap starts large and shrinks each pass until it becomes 1, at which point it acts as a regular Insertion Sort.

[table=2, #141f21]
[cell]  [color=#a0a0a0]Time Complexity:[/color]  [/cell][cell]  [color=#00FFED]O(n log n) to O(n²) based on gap[/color]  [/cell]
[cell]  [color=#a0a0a0]Space Complexity:[/color]  [/cell][cell]  [color=#00FFED]O(1) Auxiliary[/color]  [/cell]
[/table]


[color=#00FFED][font_size=22][b]2. Step-by-step example with [8, 3, 5, 1] (Gap = 2)[/b][/font_size][/color]
[b]Gap = 2:[/b]
  • Compare 8 and 5 → [color=#ff5555]swap[/color] → [5, 3, 8, 1]
  • Compare 3 and 1 → [color=#ff5555]swap[/color] → [5, 1, 8, 3]
[b]Gap = 1 (Insertion Sort):[/b]
  • Compare 5 and 1 → [color=#ff5555]swap[/color] → [1, 5, 8, 3]
  • Compare 8 and 3 → [color=#ff5555]swap[/color] → [1, 5, 3, 8]
  • Compare 5 and 3 → [color=#ff5555]swap[/color] → [1, 3, 5, 8]
[b]Done:[/b] [color=#00FFED][1, 3, 5, 8][/color]


[color=#00FFED][font_size=22][b]3. Pseudocode[/b][/font_size][/color]
[font_size=18]
[color=#ff79c6]FUNC[/color] [color=#50fa7b]shellSort[/color](AR):
    [color=#f1fa8c]LET[/color] n = AR.length
    [color=#f1fa8c]LET[/color] gap = n / 2
    [color=#ff79c6]WHILE[/color] gap > 0:
        [color=#ff79c6]FOR[/color] i [color=#ff79c6]FROM[/color] gap [color=#ff79c6]TO[/color] n-1:
            [color=#f1fa8c]LET[/color] temp = AR[i]
            [color=#f1fa8c]LET[/color] j = i
            [color=#ff79c6]WHILE[/color] j >= gap [color=#ff79c6]AND[/color] AR[j-gap] > temp:
                AR[j] = AR[j-gap]
                j = j - gap
            AR[j] = temp
        gap = gap / 2
    [color=#ff79c6]RETURN[/color] AR
[color=#a0a0a0]Reference:[/color] [url=https://www.geeksforgeeks.org/dsa/shell-sort/]GeeksForGeeks - Shell Sort[/url]",

	# --- HEAP SORT ---
	"[color=#00FFED][font_size=22][b]1. How it works[/b][/font_size][/color]
Heap Sort utilizes a structural [b]max-heap[/b] where the parent nodes stay larger than their children. It turns the unsorted array into this heap, pulls the absolute largest element from the root, slots it into the final array indices, and re-heapifies the remaining elements.

[table=2, #141f21]
[cell]  [color=#a0a0a0]Time Complexity:[/color]  [/cell][cell]  [color=#00FFED]O(n log n) Guaranteed[/color]  [/cell]
[cell]  [color=#a0a0a0]Space Complexity:[/color]  [/cell][cell]  [color=#00FFED]O(1) Auxiliary[/color]  [/cell]
[/table]


[color=#00FFED][font_size=22][b]2. Step-by-step example with [4, 2, 7, 1][/b][/font_size][/color]
  • [b]Build Max-Heap:[/b] Rearrange matrix elements → [7, 2, 4, 1]
  • [b]Extract Max 1:[/b] Swap 7 with last → [1, 2, 4, [b]7[/b]] → Heapify remaining → [4, 2, 1]
  • [b]Extract Max 2:[/b] Swap 4 with last → [1, 2, [b]4[/b], [b]7[/b]] → Heapify remaining → [2, 1]
  • [b]Extract Max 3:[/b] Swap 2 with last → [1, [b]2[/b], [b]4[/b], [b]7[/b]]
[b]Done:[/b] [color=#00FFED][1, 2, 4, 7][/color]


[color=#00FFED][font_size=22][b]3. Pseudocode[/b][/font_size][/color]
[font_size=18]
[color=#ff79c6]FUNC[/color] [color=#50fa7b]heapSort[/color](AR):
    [color=#f1fa8c]LET[/color] n = AR.length
    [color=#ff79c6]FOR[/color] i [color=#ff79c6]FROM[/color] n/2-1 [color=#ff79c6]DOWN TO[/color] 0:
        [color=#50fa7b]heapify[/color](AR, n, i)
    [color=#ff79c6]FOR[/color] i [color=#ff79c6]FROM[/color] n-1 [color=#ff79c6]DOWN TO[/color] 1:
        [color=#50fa7b]SWAP[/color](AR[0], AR[i])
        [color=#50fa7b]heapify[/color](AR, i, 0)
    [color=#ff79c6]RETURN[/color] AR

[color=#ff79c6]FUNC[/color] [color=#50fa7b]heapify[/color](AR, n, i):
    [color=#f1fa8c]LET[/color] largest = i
    [color=#f1fa8c]LET[/color] left = 2*i + 1
    [color=#f1fa8c]LET[/color] right = 2*i + 2
    [color=#ff79c6]IF[/color] left < n [color=#ff79c6]AND[/color] AR[lb]left[rb] is greater than AR[lb]largest[rb]:
        largest = left
    [color=#ff79c6]IF[/color] right < n [color=#ff79c6]AND[/color] AR[lb]right[rb] is greater than AR[lb]largest[rb]:
        largest = right
    [color=#ff79c6]IF[/color] largest != i:
        [color=#50fa7b]SWAP[/color](AR[lb]i[rb], AR[lb]largest[rb])
        [color=#50fa7b]heapify[/color](AR, n, largest)
[color=#a0a0a0]Reference:[/color] [url=https://www.geeksforgeeks.org/dsa/heap-sort/]GeeksForGeeks - Heap Sort[/url]",

	# --- BUCKET SORT ---
	"[color=#00FFED][font_size=22][b]1. How it works[/b][/font_size][/color]
Bucket Sort distributes elements into multiple sub-containers called buckets based on value boundaries. Each specific bucket then handles its own internal sorting sequences (typically via Insertion Sort) before they merge together at the end.

[table=2, #141f21]
[cell]  [color=#a0a0a0]Time Complexity:[/color]  [/cell][cell]  [color=#00FFED]O(n + k) average, O(n²) worst[/color]  [/cell]
[cell]  [color=#a0a0a0]Space Complexity:[/color]  [/cell][cell]  [color=#00FFED]O(n + k) Linear Scaling[/color]  [/cell]
[/table]


[color=#00FFED][font_size=22][b]2. Step-by-step example with [0.42, 0.11, 0.78, 0.30] (4 Buckets)[/b][/font_size][/color]
  • [b]Scatter/Distribute Map:[/b]
      - Bucket 0: [0.11]
      - Bucket 1: [0.42, 0.30]
      - Bucket 2: []
      - Bucket 3: [0.78]
  • [b]Sort Elements (Insertion Sort):[/b]
      - Bucket 1 Sort Result → [0.30, 0.42]
  • [b]Gather / Concatenate Buckets:[/b] Append lists sequentially.
[b]Done:[/b] [color=#00FFED][0.11, 0.30, 0.42, 0.78][/color]


[color=#00FFED][font_size=22][b]3. Pseudocode[/b][/font_size][/color]
[font_size=18]
[color=#ff79c6]FUNC[/color] [color=#50fa7b]bucketSort[/color](AR):
    [color=#f1fa8c]LET[/color] n = AR.length
    [color=#f1fa8c]LET[/color] buckets = array of n empty sublists
    [color=#ff79c6]FOR[/color] i [color=#ff79c6]FROM[/color] 0 [color=#ff79c6]TO[/color] n-1:
        [color=#f1fa8c]LET[/color] idx = floor(n * AR[i])
        buckets[idx].append(AR[i])
    [color=#ff79c6]FOR[/color] each individual bucket:
        [color=#50fa7b]insertionSort[/color](bucket)
    [color=#ff79c6]RETURN[/color] concatenate_all(buckets)
[color=#a0a0a0]Reference:[/color] [url=https://www.geeksforgeeks.org/dsa/bucket-sort-2/]GeeksForGeeks - Bucket Sort[/url]",

	# --- RADIX SORT ---
	"[color=#00FFED][font_size=22][b]1. How it works[/b][/font_size][/color]
Radix Sort avoids direct comparative data logic entirely. It parses integers digit-by-digit, iterating from the least significant digit (ones place) up to the most significant position. At each level, it processes stability arrays using Counting Sort.

[table=2, #141f21]
[cell]  [color=#a0a0a0]Time Complexity:[/color]  [/cell][cell]  [color=#00FFED]O(n × k) where k = digit width[/color]  [/cell]
[cell]  [color=#a0a0a0]Space Complexity:[/color]  [/cell][cell]  [color=#00FFED]O(n + k) Non-comparative[/color]  [/cell]
[/table]


[color=#00FFED][font_size=22][b]2. Step-by-step example with [170, 45, 75, 90, 2][/b][/font_size][/color]
  • [b]Pass 1 (Ones Place):[/b] Sort values → [17[b]0[/b], 9[b]0[/b], [b]2[/b], 4[b]5[/b], 7[b]5[/b]]
  • [b]Pass 2 (Tens Place):[/b] Sort values → [02, [b]4[/b]5, [b]7[/b]5, 1[b]7[/b]0, [b]9[/b]0]
  • [b]Pass 3 (Hundreds Place):[/b] Sort values → [002, 045, 075, 090, [b]1[/b]70]
[b]Done:[/b] [color=#00FFED][2, 45, 75, 90, 170][/color]


[color=#00FFED][font_size=22][b]3. Pseudocode[/b][/font_size][/color]
[font_size=18]
[color=#ff79c6]FUNC[/color] [color=#50fa7b]radixSort[/color](AR):
    [color=#f1fa8c]LET[/color] max = [color=#50fa7b]findMax[/color](AR)
    [color=#f1fa8c]LET[/color] exp = 1
    [color=#ff79c6]WHILE[/color] max / exp > 0:
        [color=#50fa7b]countingSortByDigit[/color](AR, exp)
        exp = exp * 10
    [color=#ff79c6]RETURN[/color] AR

[color=#ff79c6]FUNC[/color] [color=#50fa7b]countingSortByDigit[/color](AR, exp):
    [color=#f1fa8c]LET[/color] n = AR.length
    [color=#f1fa8c]LET[/color] output = array of size n
    [color=#f1fa8c]LET[/color] count = array of size 10 initialized to 0
    [color=#ff79c6]FOR[/color] i [color=#ff79c6]FROM[/color] 0 [color=#ff79c6]TO[/color] n-1:
        [color=#f1fa8c]LET[/color] digit = (AR[i] / exp) % 10
        count[digit]++
    [color=#ff79c6]FOR[/color] i [color=#ff79c6]FROM[/color] 1 [color=#ff79c6]TO[/color] 9:
        count[i] += count[i-1]
    [color=#ff79c6]FOR[/color] i [color=#ff79c6]FROM[/color] n-1 [color=#ff79c6]DOWN TO[/color] 0:
        [color=#f1fa8c]LET[/color] digit = (AR[i] / exp) % 10
        output[count[digit]-1] = AR[i]
        count[digit]--
    [color=#50fa7b]COPY[/color] output [color=#ff79c6]TO[/color] AR
[color=#a0a0a0]Reference:[/color] [url=https://www.geeksforgeeks.org/dsa/radix-sort/]GeeksForGeeks - Radix Sort[/url]",
]

func _ready() -> void:
	option_button.item_selected.connect(_on_item_selected)
	if back_button != null and not back_button.is_connected("pressed", Callable(self, "_on_back_pressed")):
		back_button.connect("pressed", Callable(self, "_on_back_pressed"))
	_populate(0)


func _on_back_pressed() -> void:
	var flow: Node = get_node_or_null("/root/SceneFlow")
	if flow != null:
		flow.call("goto_main_menu")
		
func _on_item_selected(index: int) -> void:
	_populate(index)
	
func _populate(index: int) -> void:
	title_label.text = TITLES[index]
	content_label.text = CONTENTS[index]
