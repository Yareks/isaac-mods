local function rgbToColor(r, g, b)
    return Color(r / 255, g / 255, b / 255, 1)
end

local typeToColor = {

    [EntityType.ENTITY_GURGLE] = {
        [0] = rgbToColor(0, 255, 0)
    },

    [EntityType.ENTITY_SPLASHER] = {
        [0] = rgbToColor(0, 255, 0)
    },

    [EntityType.ENTITY_SUCKER] = {
        [1] = rgbToColor(0, 255, 0),
        [3] = rgbToColor(255, 255, 255),
    },

    [EntityType.ENTITY_LEAPER] = {
        [1] = rgbToColor(255, 255, 255)
    },

    [EntityType.ENTITY_CLOTTY] = {
        [1] = rgbToColor(255, 255, 255),
    },

    [EntityType.ENTITY_BOIL] = {
        [1] = rgbToColor(0, 255, 0)
    },

    [EntityType.ENTITY_WALKINGBOIL] = {
        [1] = rgbToColor(0, 255, 0)
    },

    [EntityType.ENTITY_TARBOY] = {
        [0] = rgbToColor(255, 255, 255)
    },

    [EntityType.ENTITY_REVENANT] = {
        [0] = rgbToColor(215, 112, 255),
        [1] = rgbToColor(215, 112, 255)
    },

    [EntityType.ENTITY_STONEHEAD] = {
        [1] = rgbToColor(0, 255, 0)
    },

    [EntityType.ENTITY_ROUNDY] = {
        [0] = rgbToColor(0, 255, 0)
    },

    [EntityType.ENTITY_BUTT_SLICKER] = {
        [0] = rgbToColor(255, 255, 255)
    },

    -- why is gish a variant of monstro 2 lol
    [EntityType.ENTITY_MONSTRO2] = {
        [1] = rgbToColor(255, 255, 255)
    },

    [EntityType.ENTITY_BLOATY] = {
        [0] = rgbToColor(0, 255, 0)
    },

    [EntityType.ENTITY_ROUND_WORM] = {
        [3] = rgbToColor(0, 255, 0)
    },

    [EntityType.ENTITY_DELIRIUM] = {
        [0] = rgbToColor(255, 255, 255)
    },

    [EntityType.ENTITY_SLOTH] = {
        [0] = rgbToColor(0, 255, 0),
        [1] = rgbToColor(0, 255, 0)
    },

    [EntityType.ENTITY_BEAST] = {
        [20] = rgbToColor(0, 255, 0)
    },

    [EntityType.ENTITY_PESTILENCE] = {
        [0] = rgbToColor(0, 255, 0)
    },
}

return typeToColor