'''
Amazon WebScraper for Yankee Candle Reviews
Sophie Schmidt
4/3/22
Version 2.0

This webscraping script is part one of a project intended to investigate correlation between 1 star Yankee Candle Reviews on Amazon and positive Covid cases.
The complete data and the other parts of this project can be found at https://github.com/schmi-soph 
'''

# import libraries
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import NoSuchElementException
import csv
import re

# initialize webdriver and set path
driver = webdriver.Chrome('chromedriver')
path = 'https://www.amazon.com/stores/page/3F833741-88A0-43EE-BB12-EC9FB09383F7?ingress=2&visitId=feb864eb-7d2b-420c-8418-91c6425d3f03&ref_=ast_bln'

# write columns to csv
columns = ['','Username', 'Stars', 'Title', 'LocationDate', 'Size', 'Style', 'Pattern', 'Verified', 'Review', 'Helpful', 'Abuse', 'Showing', 'Zero', 'Comments', 'Problem']
with open('scrapedata.csv', 'w', newline = '', encoding = 'UTF8') as file:
    writer = csv.writer(file)
    writer.writerow(columns)

# webscraper function
def scrape_data(driver, path):

    driver.get(path)
    urls = driver.find_elements(By.CLASS_NAME, 'style__overlay__2qYgu')

    # loop through list of candles
    for i in range(len(urls)):

        # return to path and continue to next candle
        driver.get(path)
        link = driver.find_elements(By.CLASS_NAME, 'style__overlay__2qYgu')[i]
        link.click()
        
        # find all reviews
        next = driver.find_element(By.XPATH, "//a[@data-hook = 'see-all-reviews-link-foot']")
        next.click()
        
        # click through every page of reviews
        while True:

            # collect source code 
            driver.refresh()
            page = driver.page_source
            soup = BeautifulSoup(page, 'html.parser')
            soup = BeautifulSoup(soup.prettify(), 'html.parser')

            # extract review data
            for data in soup.findAll("div", {"data-hook":"review"}):
                data = data.get_text()
                data = re.split(r'\s\s\s\s\s+', data)

                # write review data to csv
                with open('ScrapeData.csv', 'a+', newline = '', encoding = 'UTF8') as file:
                    writer = csv.writer(file)
                    writer.writerow(data)

            # determine if the last page has been reached
            try:
                driver.find_element(By.XPATH, "//li[@class = 'a-last']").click()
            except NoSuchElementException:
                break

    driver.close()

if __name__ == '__main__':
    scrape_data(driver, path)