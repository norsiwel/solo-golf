def extract_textures(env, output_dir):
    tex_dir = os.path.join(output_dir, "textures")
    os.makedirs(tex_dir, exist_ok=True)

    extracted = 0
    skipped = 0
    texture_map = {}

    for obj in env.objects:
        if obj.type.name != "Texture2D":
            continue
        try:
            data = obj.read()
            img = data.image
            if not img:
                skipped += 1
                continue

            safe_name = "".join(
                c if c.isalnum() or c in "-_." else "_"
                for c in data.m_Name
            )
            out_path = os.path.join(tex_dir, f"{safe_name}.png")
            img.save(out_path)
            extracted += 1

            surface = classify_texture(data.m_Name)
            print(f"  Texture: {data.m_Name} ({img.size[0]}x{img.size[1]}) -> {surface}")

            if surface != "unknown":
                if surface not in texture_map:
                    texture_map[surface] = f"{safe_name}.png"

        except Exception as ex:
            skipped += 1

    print(f"  Extracted {extracted} textures, classified {len(texture_map)}")
    return extracted, texture_map