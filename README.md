# Scaling the Tiles

**A scalable edge-matching puzzle game built with Godot 4.4 and GDScript.**

Scaling the Tiles is my final-year Computer Science project. Inspired by Wang tiles, it extends traditional edge-matching puzzles by allowing tiles to have multiple coloured segments along each edge. Players can resize tiles horizontally and vertically to align these segments, creating puzzles that require both spatial reasoning and experimentation.

The project covers the full software development lifecycle, from background research and requirements analysis through system design, implementation, testing and evaluation.

## Features

* **Tile manipulation:** Drag, resize, duplicate and delete tiles.
* **Intelligent snapping:** Compatible edges snap together based on colour, direction, proximity and segment length.
* **Tile grouping:** Connected tiles can be moved or duplicated as a group, or separated individually.
* **Procedural puzzle generation:** Generate solvable puzzles with easy, medium and hard difficulty presets.
* **Pre-built puzzles:** Three introductory levels demonstrate resizing, duplication and repeated tile use.
* **Hint system:** Reveal tiles from a known solution when stuck.
* **Accessibility settings:** Five colour palettes, including alternatives designed for different forms of colour-vision deficiency and a high-contrast option.

## Technical Highlights

### Procedural puzzle generation

The generator constructs a solution before deriving the puzzle pieces, ensuring that every generated puzzle has at least one valid arrangement.

It creates a grid of coloured boundaries and uses recursive **Binary Space Partitioning (BSP)** to divide the space into rectangles of varying sizes. Each rectangle becomes a tile whose edge segments are derived from the underlying grid.

Difficulty is adjusted through parameters including grid size, colour count, partition depth and colour-pattern repetition.

### Tile matching and resizing

Each tile consists of four edges containing ordered sequences of coloured segments. When a tile is moved near another, the matching logic checks segment colour, direction, proximity and physical length.

Compatible tiles snap together, with small size differences automatically corrected. Additional validation prevents overlaps and conflicting connections with neighbouring tiles.

### Modular architecture

The game uses Godot's scene and node system, custom resources for puzzle data, and signals for communication between components. Tile interactions are managed through separate idle, dragging and resizing states to prevent conflicting inputs.

## Technologies

* **Godot Engine 4.4**
* **GDScript**
* **Git and GitHub**

## Getting Started

1. Install [Godot Engine 4.4](https://godotengine.org/download/archive/4.4-stable/).

2. Clone this repository:

   ```bash
   git clone https://github.com/ftma48/Scaling-the-Tiles.git
   ```

3. Open Godot and import the `project.godot` file.

4. Run the project from the Godot editor.

## How to Play

Select a pre-built puzzle or generate a new one using a difficulty preset. Drag tiles onto the board and resize them until adjacent coloured segments align.

* **Drag:** Move a tile or connected group.
* **Resize:** Drag a tile's edge or corner handles.
* **Right-click:** Select a tile to enable duplication and deletion controls.
* **Shift-click:** Disconnect a tile from its group.

Complete the puzzle by arranging the tiles into a valid layout that satisfies the board's boundary constraints.

## Project Structure

| Directory       | Contents                                   |
| --------------- | ------------------------------------------ |
| `globals/`      | Shared game state and global functionality |
| `images/`       | Image assets                               |
| `puzzles/`      | Puzzle resources                           |
| `resources/`    | Game resources and data                    |
| `scenes/`       | Godot scenes                               |
| `scripts/`      | Gameplay logic                             |
| `ui/`           | User interface components                  |
| `project.godot` | Godot project configuration                |

## Testing and Evaluation

The project was evaluated through functional testing and usability interviews with four participants.

Functional testing covered tile movement, snapping, grouping, resizing, completion detection, puzzle generation and other core mechanics. User feedback helped identify interaction issues and opportunities to improve puzzle difficulty and onboarding.

The user study was small, and the alternative colour palettes were not tested with colour-blind participants. Further evaluation would be needed to assess their effectiveness.

## Limitations and Future Work

Several planned extensions were outside the final project's scope, including a general-purpose puzzle solver, infinite tiling visualisation, camera zoom and panning, and a timer.

The implemented hint system uses the known solution stored during puzzle generation rather than a general solver.

Potential future improvements include more systematic difficulty balancing, a tutorial, expanded accessibility testing and a constrained puzzle solver.

## About

Developed as an individual final-year Computer Science project at the University of Sussex.
