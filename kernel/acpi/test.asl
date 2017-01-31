
DefinitionBlock ("test.aml", "DSDT", 1, "LENOVO", "CB-01   ", 0x00000001)
{
	Scope(_SB)
	{
		// Serial Port
		OperationRegion(SERL, SystemIO, 0x3F8, 1)
		Field(SERL, ByteAcc, NoLock, Preserve)
		{
			COMB, 8
		}

		// Screen Framebuffer (QEMU ONLY!!)
		OperationRegion(SCRN, SystemMemory, 0xFD024040, 12)
		Field(SCRN, DWordAcc, NoLock, Preserve)
		{
			TST1, 32,
		}

		// Test Method -- This should write "Hi!" to the serial port
		// And put a white pixel near the top-left of the screen
		// The pixel part only works in QEMU because hard-coded framebuffer address
		Method(WRTT, 0, Serialized)
		{
			COMB = 0x48	// 'H'
			COMB = 0x69	// 'i'
			COMB = 0x21	// '!'
			COMB = 13	// '\c'
			COMB = 10	// '\n'
			TST1 = 0xFFFFFF
			
			Return(0xFA6)
		}
	}

	Name(_PRT, Package(2)
	{
		Package(4) { 1,2,3,4 },
		Package(4) { 5,6,7,8 }
	})

	// For testing returning packages and package parsing
	Method(_S4_, 0, Serialized)
	{
		Return(Package(4)
		{
			4,1,0,0
		})
	}

	Method(_S5_, 0, Serialized)
	{
		Name(S5PK, Package(4)
		{
			0,0,0,0
		})
		Return(S5PK)
	}

}


