-- Catppuccin Mocha, matching the desktop and the other tools.
-- The COSMIC theme is the catppuccin/cosmic-desktop port, tracked in cosmic/.
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "mocha",
      integrations = {
        cmp = true,
        gitsigns = true,
        mini = { enabled = true },
        neotree = true,
        telescope = true,
        treesitter = true,
        which_key = true,
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "catppuccin" },
  },
}
