# Asset Reverse-Engineering Research Plan

## Goal
To reverse-engineer the proprietary `.RAW`, `.z2raw`, and `.bin` asset formats from the original game (`original/TradeNations.app/bundle/`) into a usable format (e.g., PNG for images, standard animation formats) for integration into the Godot project.

## Initial Focus: `.RAW` Image Format

The `.RAW` format will be the initial focus, as it appears to represent static image data (sprites, UI elements) and is likely simpler than the animation formats.

### Research Steps

1.  **Tool Identification:**
    *   Identify and set up hex editors (e.g., HxD, 010 Editor) for inspecting raw binary data.
    *   Identify image analysis tools that can handle raw pixel data or provide insights into image structure.

2.  **Format Inference:**
    *   **File Analysis**: Systematically examine `.RAW` files. Look for:
        *   **Magic Numbers**: Any repeating byte sequences at the beginning or specific offsets that might indicate a file type or version.
        *   **Metadata**: Look for embedded strings or integer values that could represent width, height, color depth (e.g., 8-bit, 24-bit, 32-bit), or pixel data start offset.
        *   **Pixel Arrangement**: Determine if the pixel data is RGB, RGBA, BGR, ABGR, indexed color, etc. Identify endianness.
        *   **Compression**: Look for signs of common compression algorithms (e.g., zlib, LZMA) if direct pixel data isn't obvious.
    *   **Comparison with PNG Counterparts**: Utilize `.RAW` files that have known `.PNG` counterparts (e.g., `20_MOREBARREL.RAW` vs `20_MOREBARREL.PNG`).
        *   Compare file sizes and content to deduce differences and potential compression/encoding.
        *   If dimensions are known from the PNG, attempt to calculate expected `.RAW` file size based on assumed color depths (e.g., `width * height * bytes_per_pixel`).

3.  **Conversion Script Development (Iterative):**
    *   **Prototype**: Develop a small, standalone Python script or Godot Editor Plugin to attempt to read and interpret the `.RAW` file format.
    *   **Single File Conversion**: The initial goal is to successfully convert a single `.RAW` image into a standard, viewable format (e.g., PNG).
    *   **Validation**: Verify the converted image against the known `.PNG` counterpart for accuracy.

## Future Focus: `.z2raw` + `*_Timeline.bin` + `*_TimelineFormatIndex.json` Animation Format

Once `.RAW` image conversion is successful, research will extend to the animation formats.

### Community Research & Findings (Battle Nations / Trade Nations Internals)

Based on community reverse-engineering efforts from the Z2Live sister title *Battle Nations* (which shares identical internal engine formats and rendering schemas), we have identified the following specifications:

1. **`.z2raw` Files (Proprietary Texture Sheets)**
   - **Container**: Propriertary bitmap sheets storing texture atlases.
   - **Header**: Begins with a magic metadata string denoting version/magic and pixel layout.
     * *Example header*: `I17 <Internal_Name> RAW4444` (or `RAW8888`).
     * `RAW4444` indicates 16-bit color (4 bits per channel for ARGB), a common mobile compression optimization.
     * `RAW8888` indicates high-fidelity 32-bit color (8 bits per channel).
   - **Compression**: Pixel data following the header is compressed using standard **zlib** compression.

2. **`.bin` / `.anim` Files (Compositing & Animation Timelines)**
   - **Composition Maps**: Defines coordinates (X, Y, Width, Height) to slice the components (e.g. arms, heads, wheels) out of the `.z2raw` sheet.
   - **Frame Assembly**: Instructs the renderer on how to compile these slices (layering, scaling, and rotation angles) into a single unified frame.
   - **Animation Sequences**: Sequences keyframes with relative durations to form movement states (like `idle`, `walk`, `produce`, `attack`).
   - **Community Reference Tools**: The Bobmath/Drullkus *Animation Grabber* community tool parses the `.bin` to automatically slice, compose, and export `.z2raw` assets into animated standard formats (such as PNG sheets or GIFs).

### Initial Research Considerations

*   `*_TimelineFormatIndex.json` might provide hints about the content within the `.bin` files.
*   Binary-diffing multiple `_Timeline.bin` files (especially those related to known animations) could reveal patterns or data structures.
*   This will likely be a more complex task, possibly requiring knowledge of animation data structures (keyframes, bone data, interpolation curves).

## Deliverables

*   **Research Notes**: Documented findings on file structures, identified patterns, and potential conversion methods.
*   **Python/Godot Conversion Tool**: A script or tool capable of converting identified `.RAW` assets to standard image formats.
*   **Proof-of-Concept**: Successful conversion and display of at least one original game asset within the Godot project.
