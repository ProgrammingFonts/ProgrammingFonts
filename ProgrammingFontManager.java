package com.ifeegoo.demo.font;

/**
 * <p>
 * Programming Font Manager.
 * </p>
 * 
 * @author ifeegoo
 * 
 * @since 1.0.0
 */
public final class ProgrammingFontManager
{
	/**
	 * <p>
	 * The font is fantastic or not.
	 * </p>
	 * 
	 * @param font
	 *            Font.
	 * 
	 * @return TRUE:The font is fantastic.FALSE:The font is not fantastic.
	 * 
	 * @see ProgrammingFontManager.Font
	 */
	public static boolean isFantastic(int font)
	{
		String[] strings = new String[]{"1234567890",
				                        "ABCDEFGHIJKLMNOPQRSTUVWXYZ", 
				                        "abcdefghijklmnopqrstuvwxyz",
				                        "ΑΒΓΔΕΖΗΘΙΚ∧ΜΝΞΟ∏Ρ∑ΤΥΦΧΨΩ",
				                        "αβγδεζηθικλμνξοπρστυφχψω",
				                        "!@#$%^&*()_+-={}|[]':;<>,.?"};
		System.out.println(strings);
		return true;
	}
}
  
