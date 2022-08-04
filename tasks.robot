*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.Browser.Selenium
Library             RPA.HTTP
Library             RPA.Tables
Library             RPA.PDF
Library             RPA.Archive
Library             RPA.Dialogs
Library             RPA.Robocorp.Vault
Library             RPA.RobotLogListener
Library             RPA.Desktop


*** Variables ***
${ORDERS_CSV_OUTPUT_PATH}=          ${OUTPUT_DIR}${/}data${/}orders.csv
${TEMP_ROBOT_SCREENSHOT_PATH}=      ${OUTPUT_DIR}${/}data${/}temp${/}robot-preview.png
${RECEIPTS_OUTPUT_FOLDER}=          ${OUTPUT_DIR}${/}data${/}receipts


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    ${orders_csv_url}=    Input CSV URL
    ${orders_url}=    Obtain order website URL from vault
    Open the robot order website    ${orders_url}
    ${orders}=    Get orders    ${orders_csv_url}
    FOR    ${row}    IN    @{orders}
        Log    Current Row is: ${row}
        Close the annoying modal
        Fill the form    ${row}
        Preview the robot
        Wait Until Keyword Succeeds    5x    0.5 sec    Submit the order
        ${pdf_path}=    Store the receipt as a PDF file    ${row}[Order number]
        ${robot_image_path}=    Take a screenshot of the robot    ${row}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${robot_image_path}    ${pdf_path}
        Go to order another robot
    END
    Create a ZIP file of the receipts
    [Teardown]    Close All Browsers


*** Keywords ***
Input CSV URL
    [Documentation]    Open a dialog that asks the user for the URL from which the robot orders CSV file will be downloaded.
    Add heading    Please provide the CSV Download URL!
    Add text    A good URL would be: https://robotsparebinindustries.com/orders.csv    size=Small
    Add text input    url
    ...    label=URL
    ...    placeholder=Enter CSV URL here
    ${result}=    Run dialog
    RETURN    ${result.url}

Obtain order website URL from vault
    [Documentation]    Get the URL of the robot orders website from the vault.
    ${orders_url}=    Get Secret    robot-orders
    Log    Obtained robot order website URL from vault is: ${orders_url}[url]
    RETURN    ${orders_url}[url]

Open the robot order website
    [Documentation]    Open the a browser with the given URL pointing to the robot orders website.
    [Arguments]    ${orders_url}
    Open Available Browser    ${orders_url}

Get orders
    [Documentation]    Download the robot orders CSV file from the given URL and return the CSV file as a table.
    [Arguments]    ${orders_csv_url}
    TRY
        Download    ${orders_csv_url}    overwrite=True    target_file=${ORDERS_CSV_OUTPUT_PATH}
    EXCEPT
        Log    Could not download orders CSV file. Check if your provided download URL is correct!    ERROR
        Show CSV Download Error Dialog
        Fail    Failed to download orders CSV
    END
    ${orders}=    Read table from CSV    ${ORDERS_CSV_OUTPUT_PATH}
    Log    Found columns: ${orders.columns}
    RETURN    ${orders}

Show CSV Download Error Dialog
    [Documentation]    Show an error dialog, informing the user that the orders CSV
    ...    file download could not be completed, likely because the provided URL is probably wrong.
    Add heading    Failed to download orders CSV file!
    Add text    There was an error while trying to download the orders CSV file.
    Add text    Maybe the URL you have given is wrong?    size=Small
    Run dialog

Close the annoying modal
    [Documentation]    Close the pop-up that occurs when opening the robot orders website by pressing the "OK" button.
    Click Button    xpath: //*[contains(text(), "OK")]

Fill the form
    [Documentation]    Fill out the robot order form with the given row of the orders table.
    [Arguments]    ${row}
    Select From List By Index    id:head    ${row}[Head]
    Click Element    id:id-body-${row}[Body]
    Input Text    xpath: //input[@type="number"]    ${row}[Legs]
    Input Text    id:address    ${row}[Address]

Preview the robot
    [Documentation]    Click the according button to show a preview image of the robot.
    Click Button    id:preview

Store the receipt as a PDF file
    [Documentation]    Wait for the receipt to appear, then get the HTML of the
    ...    receipt and store it as a PDF file, that conatins the order number in its name.
    [Arguments]    ${order_number}
    Wait Until Element Is Visible    id:receipt
    ${receipt_html}=    Get Element Attribute    id:receipt    outerHTML
    ${pdf_path}=    Set Variable    ${RECEIPTS_OUTPUT_FOLDER}${/}receipt_${order_number}.pdf
    Html To Pdf    ${receipt_html}    ${pdf_path}
    RETURN    ${pdf_path}

Take a screenshot of the robot
    [Documentation]    Take a screenshot of the robot preview image.
    [Arguments]    ${order_number}
    ${image_output_path}=    Set Variable    ${TEMP_ROBOT_SCREENSHOT_PATH}
    Screenshot    id:robot-preview-image    ${image_output_path}
    RETURN    ${image_output_path}

Embed the robot screenshot to the receipt PDF file
    [Documentation]    Open the receipt PDF file and append the given robot image. Close the PDF when finished.
    [Arguments]    ${image_path}    ${pdf_path}
    Add Watermark Image To Pdf    ${image_path}    ${pdf_path}    source_path=${pdf_path}
    Close Pdf    ${pdf_path}

Submit the order
    [Documentation]    Click the order button to submit the order and wait for
    ...    the receipt to be visible. If the receipt is not shown, an error occured
    ...    when submitting and this keyword will throw and error.
    Click Button    id:order
    # Since this is an expected error, we will not always take a screenshot if the "Element Should Be Visible" keyword fails.
    # Thus, we are using the "Mute Run On Failure" keyword to take no actions upon failure of the given keyword.
    Mute Run On Failure    Element Should Be Visible
    Element Should Be Visible    id:receipt

Go to order another robot
    [Documentation]    Click the button to proceed to the next robot order.
    Click Button    id:order-another

Create a ZIP file of the receipts
    [Documentation]    Create a zip archive of all created receipt PDF
    ...    documents and store the archive in the output directory.
    Archive Folder With Zip    ${RECEIPTS_OUTPUT_FOLDER}    ${OUTPUT_DIR}/receipts.zip
