// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


#import "ZMBaseManagedObjectTest.h"


@interface PersonNameTests : ZMBaseManagedObjectTest
@property (nonatomic) NSLinguisticTagger *tagger;
@end

@implementation PersonNameTests

- (void)setUp
{
    [super setUp];
    self.tagger = [[NSLinguisticTagger alloc] initWithTagSchemes:@[NSLinguisticTagSchemeScript] options:0];
}

- (void)tearDown
{
    [super tearDown];
    self.tagger = nil;
}

+ (void)tearDown
{
    [super tearDown];
    
}

- (void)testThatNameIsSeparatedIntoComponents
{
    //given
    
    NSString *nameWithSpace = @"  Henry The Great Emporer";
    NSString *nameWithLineBreak = @"The Name \n Break Name";
    
    // when
    PersonName *nameWithSpaceComp = [PersonName personWithName:nameWithSpace schemeTagger:self.tagger];
    PersonName *nameWithLineBreakComp = [PersonName personWithName:nameWithLineBreak schemeTagger:self.tagger];
    
    //then
    NSArray *nameWithSpaceArray = @[@"Henry", @"The", @"Great", @"Emporer"];
    NSArray *nameWithLineBreakArray = @[@"The", @"Name", @"Break", @"Name"];
    
    XCTAssertEqualObjects(nameWithSpaceComp.components, nameWithSpaceArray);
    XCTAssertEqualObjects(nameWithLineBreakComp.components, nameWithLineBreakArray);

}

- (void)testThatItTrimsSpecialCharacters
{
    // given
    NSString *name1 = @"Henry (The) Great Emporer";
    NSString *name2 = @"The *Starred* Name";
    
    // when
    PersonName *nameComp1 = [PersonName personWithName:name1 schemeTagger:self.tagger];
    PersonName *nameComp2 = [PersonName personWithName:name2 schemeTagger:self.tagger];
    
    // then
    NSArray *nameArray1 = @[@"Henry", @"The", @"Great", @"Emporer"];
    NSArray *nameArray2 = @[@"The", @"Starred", @"Name"];
    
    XCTAssertEqualObjects(nameComp1.components, nameArray1);
    XCTAssertEqualObjects(nameComp2.components, nameArray2);
}

- (void)testThatItRemovesEmptyComponentFromComponents
{
    // given
    NSString *name1 = @"Henry () Great Emporer";
    NSString *name2 = @"The (   ) Empty Name";
    
    // when
    PersonName *nameComp1 = [PersonName personWithName:name1 schemeTagger:self.tagger];
    PersonName *nameComp2 = [PersonName personWithName:name2 schemeTagger:self.tagger];
    
    // then
    NSArray *nameArray1 = @[@"Henry", @"Great", @"Emporer"];
    NSArray *nameArray2 = @[@"The", @"Empty", @"Name"];
    
    XCTAssertEqualObjects(nameComp1.components, nameArray1);
    XCTAssertEqualObjects(nameComp2.components, nameArray2);
}

- (void)testThatItReturnsFirstComponentAsFirstName
{
    NSString *name1 = @"Henry The Great Emporer";
    
    PersonName *nameComp1 = [PersonName personWithName:name1 schemeTagger:self.tagger];
    
    XCTAssertEqualObjects(nameComp1.givenName, @"Henry");

}

- (void)testThatItReturnsUntrimmedStringFullName
{
    // given
    NSString *name1 = @"Henry The Great Emporer";
    NSString *name2 = @"Henry ()";
    
    // when
    PersonName *nameComp1 = [PersonName personWithName:name1 schemeTagger:self.tagger];
    PersonName *nameComp2 = [PersonName personWithName:name2 schemeTagger:self.tagger];


    // then
    XCTAssertEqualObjects(nameComp1.fullName, name1);
    XCTAssertEqualObjects(nameComp2.fullName, name2);
}


- (void)testThatItReturnsFullNameWhenStringIsEmptyAfterTrimming
{
    // given
    NSString *name1 = @"(        )";
    NSString *name2 = @"**********";
    
    // when
    PersonName *nameComp1 = [PersonName personWithName:name1 schemeTagger:self.tagger];
    PersonName *nameComp2 = [PersonName personWithName:name2 schemeTagger:self.tagger];
    
    
    // then
    XCTAssertEqualObjects(nameComp1.fullName, name1);
    XCTAssertEqualObjects(nameComp2.fullName, name2);
}

# pragma mark - Composed Character Related Tests

- (void)testThatItReturnsFirstCharacterOfFirstAndLastNameAsInitials
{
    // given
    NSString *name1 = @"\u00cbmil Super Man";
    
    // when
    PersonName *personName1 = [PersonName personWithName:name1 schemeTagger:self.tagger];

    // then
    XCTAssertEqualObjects(personName1.initials, @"\u00cbM");
}

- (void)testThatItReturnsOneCharacterWhenThereIsOnlyOneNameComponent
{
    // given
    NSString *name2 = @"E\u0308mil";
    
    // when
    PersonName *personName2 = [PersonName personWithName:name2 schemeTagger:self.tagger];
    
    // then
    XCTAssertEqualObjects(personName2.initials, @"\u00cb");
}


# pragma mark - Language Related Tests

# pragma mark - Chinese

// CHINESE NAMES http:en.wikipedia.org/wiki/Chinese_name
//
// majority - 3 syllables (chinese characters) (1 family name followed by 2 given name which are always used together)
// 14% - 2 syllable
// <0.2% -  4 or more syllables, mostly compound surnames
// there is no white space between family name and given name
//
// A boy called Wei (???) and belonging to the??Zhang??(???) family??is called "Zhang Wei" and not "Wei Zhang"
// formally addressed as "Mr. Zhang"
// informally as "Zhang Wei" ??? never as ???Wei"
//
// Romanization
// standard way of romanizing = Hanyu Pinyin
// Adoption of??European-style name??(typically??English)
// by reversing the Chinese order (e.g., "Wei Zhang")
// by choosing a new name entirely (e.g., "John Zhang???)
// by combining both English and Chinese names into a single hybrid: "John Zhang Wei".
//
// Shumeng???s comment: ???As far as I know, chinese people don???t usually use their real names on the internet though???
// Maybe we should not split them at all when they are not romanized?


- (void)testThatLinguisticTraggerRecognizesTraditionalAndSimplifiedChinese
{
    // given
    NSString *name1 = @"??????";                // zh??ng w??i - simplified Han (script code: Hans)
    NSString *name2 = @"??????";                // zh??ng w??i - traditional Han (script code: Hant)
    
    // when
    self.tagger.string = name1;
    NSArray *tags1 = [self.tagger tagsInRange:NSMakeRange(0, self.tagger.string.length) scheme:NSLinguisticTagSchemeScript options:0 tokenRanges:nil];
    
    self.tagger.string = name2;
    NSArray *tags2 = [self.tagger tagsInRange:NSMakeRange(0, self.tagger.string.length) scheme:NSLinguisticTagSchemeScript options:0 tokenRanges:nil];
    
    // then
    XCTAssertEqualObjects(tags1.firstObject, @"Hans");
    XCTAssertEqualObjects(tags2.firstObject, @"Hant");
}

- (void)testThatChineseNamesReturnOneCharactersIfTheNameConsistsOfOnlyOneCharacter
{
    // given
    NSString *name3 = @"???";
    
    // when
    PersonName *nameComp3 = [PersonName personWithName:name3 schemeTagger:self.tagger];
    
    // then
    XCTAssertEqualObjects(nameComp3.initials, @"???");
}

# pragma mark - Hindi / Devanagari

- (void)testThatLinguisticTraggerRecognizesSanskrit
{
    // given
    NSString *name1 = @"????????????????????? ?????????????????? ???????????????";    // Mohandas Karamchand Gandhi - Davanagari (script code: Deva), most commonly used script for writing Sanskrit (e.g. in Hindi, Nepali, Marathi, Konkani, Bodo and Maithili)
    NSString *name2 = @"????????????????????? ?????????????????? ???????????????";     // Mohandas Karamchand Gandhi - Gujarati (script code: Gujr)
    
    // when
    self.tagger.string = name1;
    NSArray *tags1 = [self.tagger tagsInRange:NSMakeRange(0, self.tagger.string.length) scheme:NSLinguisticTagSchemeScript options:0 tokenRanges:nil];
    
    self.tagger.string = name2;
    NSArray *tags2 = [self.tagger tagsInRange:NSMakeRange(0, self.tagger.string.length) scheme:NSLinguisticTagSchemeScript options:0 tokenRanges:nil];
    
    // then
    XCTAssertEqualObjects(tags1.firstObject, @"Deva");
    XCTAssertEqualObjects(tags2.firstObject, @"Gujr");
}

- (void)testThatHindiNamesAreSeparatedCorrectly
{
    // given
    NSString *name1 = @"????????????????????? ?????????????????? ???????????????"; // Mohandas Karamchand Gandhi - Mohandas Karamchand is the secondName, Gandhi the firstName
    
    // when
    PersonName *nameComp1 = [PersonName personWithName:name1 schemeTagger:self.tagger];
    
    // then
    XCTAssertEqualObjects(nameComp1.givenName, @"???????????????");
    XCTAssertEqualObjects(nameComp1.fullName, @"????????????????????? ?????????????????? ???????????????");
}


# pragma mark - Arabic

//     ARABIC NAMES http:en.wikipedia.org/wiki/Arabic_name
//     General structure: <given name> ibn <father??? s name> ibn <grandfather???s names> <family name>
//     ???ibn" = ???son of???
//     ???bint??? = ???daughter of???
//     ???ibn" and ???bint" are dropped in most Arab countries today
//
//     Some Arab countries use only two- and three-word names, and sometimes four-word names in official or legal matters.
//     first name = personal name
//     middle name = father's name
//     last name = family name.
//
//     Muhammad ibn Saeed ibn Abd al-Aziz al-Filasteeni
//     (Muhammad, son of Saeed, son of Abd al-Aziz, the Palestinian)
//        ???????? ???? ???????? ???? ?????? ???????????? ??????????????????
//     mu???ammad ibn sa????di ibn ??abdi l-??az??zi l-filas?????n??
//     Given Name: Muhammad
//     Called Name: Muhammad OR Abu Kareem (Father of Kareem)
//     Last Name: al-Filasteeni
//
//     Westernisation
//     Almost all Arabic-speaking countries (excluding for example Saudi Arabia or Bahrain) have now adopted a westernised way of naming.
//     no single accepted Arabic transliteration
//     ???> Abdul Rahman, Abdoul Rahman, Abdur Rahman, Abdurahman, Abd al-Rahman, or Abd ar-Rahman
//
//     Common Mistakes
//     Abdul Rahman bin Omar al-Ahmad
//     "Abdul??? means "servant of the" and is not by itself a name
//     "Abdul" / "Abd" is always followed by one of the 99 names of God (http://en.wikipedia.org/wiki/Names_of_God_in_Islam), the feminine equivalent is "Amat" / "Amah"
//     given name: ???Abdul Rahman???
//     family name: Ahmad
//
//     Sami Ben Ahmed
//     "bin" (also written as Ben) and "ibn" indicate the family chain
//     given name: Sami
//     family name: Ben Ahmed


- (void)testThatLinguisticTraggerRecognizesArabic
{
    // given
    NSString *name1 = @"???????? ???? ???????? ???? ?????? ???????????? ??????????????????";    // Muhammad ibn Saeed ibn Abd al-Aziz al-Filasteeni - Arabic (script code: Arab)
    
    // when
    self.tagger.string = name1;
    NSArray *tags1 = [self.tagger tagsInRange:NSMakeRange(0, self.tagger.string.length) scheme:NSLinguisticTagSchemeScript options:0 tokenRanges:nil];
    
    // then
    XCTAssertEqualObjects(tags1.firstObject, @"Arab");
}


- (void)testThatArabicNamesAreSeparatedCorrectly
{
    // given
    
    NSString *name1 = @"???????? ???? ???????? ???? ?????? ???????????? ??????????????????"; // Muhammad ibn Saeed ibn Abd al-Aziz al-Filasteeni, where "????????" (Muhammad) is the firstName, but "comes last" as it"s written from right to left
    NSString *name2 = @"?????? ???????? ???????????? ???? ????????????";          // Abd All??h a???-?????n?? bin al-???usain, where "?????? ????????" (Abdullah II / Abd All??h a???-?????n??) is the firstName
    NSString *name3 = @"?????? ???????????? ?????????????????";               // Amat Al'Alim Alsoswa, where "?????? ????????????" (Amat al Alim = Slave of the all knowing) is the firstName
    
    // when
    PersonName *nameComp1 = [PersonName personWithName:name1 schemeTagger:self.tagger];
    PersonName *nameComp2 = [PersonName personWithName:name2 schemeTagger:self.tagger];
    PersonName *nameComp3 = [PersonName personWithName:name3 schemeTagger:self.tagger];

    // then
    XCTAssertEqualObjects(nameComp1.givenName, @"????????");
    XCTAssertEqualObjects(nameComp1.fullName, name1);
    
    XCTAssertEqualObjects(nameComp2.givenName, @"?????? ????????");
    XCTAssertEqualObjects(nameComp2.fullName, name2);
    
    XCTAssertEqualObjects(nameComp3.givenName, @"?????? ????????????");
    XCTAssertEqualObjects(nameComp3.fullName, name3);
}

- (void)testThatItReturnsFirstLettersOFFirstAndLastComponentForArabicInitials
{
    // given
    
    NSString *name1 = @"???????? ???? ???????? ???? ?????? ???????????? ??????????????????"; // Muhammad ibn Saeed ibn Abd al-Aziz al-Filasteeni, where "????????" (Muhammad) is the firstName, but "comes last" as it"s written from right to left
    NSString *name2 = @"?????? ???????? ???????????? ???? ????????????";          // Abd All??h a???-?????n?? bin al-???usain, where "?????? ????????" (Abdullah II / Abd All??h a???-?????n??) is the firstName
    NSString *name3 = @"?????? ???????????? ?????????????????";               // Amat Al'Alim Alsoswa, where "?????? ????????????" (Amat al Alim = Slave of the all knowing) is the firstName
    
    // when
    PersonName *nameComp1 = [PersonName personWithName:name1 schemeTagger:self.tagger];
    PersonName *nameComp2 = [PersonName personWithName:name2 schemeTagger:self.tagger];
    PersonName *nameComp3 = [PersonName personWithName:name3 schemeTagger:self.tagger];
    
    // then
    XCTAssertEqualObjects(nameComp1.initials, @"????");
    XCTAssertEqualObjects(nameComp2.initials, @"????");
    XCTAssertEqualObjects(nameComp3.initials, @"????");
}

# pragma mark - Mixed Language Sets

- (void)testThatTheSecondComposedCharacterReturnsNilWhenTheStringIsShorterThan2;
{
    XCTAssertNil([@"" zmSecondComposedCharacter]);
    XCTAssertNil([@"A" zmSecondComposedCharacter]);
    XCTAssertNil([@"????" zmSecondComposedCharacter]);
}

- (void)testThatTheFirstComposedCharacterReturnsNilWhenTheStringIsEmpty;
{
    XCTAssertNil([@"" zmFirstComposedCharacter]);
}

@end
